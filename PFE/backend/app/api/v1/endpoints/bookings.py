from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status

from app.core.database import get_database
from app.core.deps import require_admin, require_client
from app.schemas.dtos import PriceEstimateRequest, TripCreate, TripStatusUpdate, TripUpdate
from app.services.pricing_calculator import calculate_price, get_route_metrics
from app.services.booking_service import (
    create_trip,
    delete_trip,
    get_pricing_rules,
    get_trip_history,
    list_trips,
    update_trip,
    update_trip_status,
)
from app.services.utils import serialize_document

router = APIRouter()

VALID_STATUSES = {"pending", "confirmed", "on_route", "completed", "cancelled"}


def _parse_ride_datetime(booking: dict) -> datetime | None:
    date_str = booking.get("departure_date") or booking.get("ride_date", "")
    time_str = booking.get("departure_time") or booking.get("ride_time", "")
    if not date_str or not time_str:
        return None
    for fmt in ["%Y-%m-%d %H:%M", "%Y-%m-%d %I:%M %p", "%Y-%m-%d %H:%M:%S"]:
        try:
            return datetime.strptime(f"{date_str} {time_str}", fmt).replace(tzinfo=timezone.utc)
        except ValueError:
            continue
    return None


def _check_time_rule(booking: dict, limit_hours: int, action: str) -> None:
    ride_dt = _parse_ride_datetime(booking)
    if ride_dt is None:
        return  # cannot parse — allow the action
    hours_until = (ride_dt - datetime.now(timezone.utc)).total_seconds() / 3600
    if hours_until < limit_hours:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"{action} is only allowed {limit_hours} hours before departure. "
                   f"Departure is in {hours_until:.1f} hours.",
        )



# ─── Client endpoints ──────────────────────────────────────────────────────────

@router.post("/price-estimate")
async def price_estimate(
    payload: PriceEstimateRequest,
    _: dict = Depends(require_client),
) -> dict:
    """Real price quote from the per-vehicle pricing parameters.

    Distance/duration via Google Directions (haversine fallback). With
    vehicle_id → single estimate; without → one estimate per available vehicle
    (single Directions call either way, so the fleet quote costs one request).
    """
    metrics = await get_route_metrics(
        payload.pickup_lat, payload.pickup_lng,
        payload.destination_lat, payload.destination_lng,
        waypoints=payload.waypoints,
    )

    db = get_database()
    if payload.vehicle_id:
        vehicle = await db.cars.find_one({"_id": payload.vehicle_id})
        if not vehicle:
            raise HTTPException(status_code=404, detail="Vehicle not found")
        estimate = calculate_price(
            vehicle, metrics["distance_km"], metrics["duration_hours"],
            payload.trip_type, payload.waypoints,
        )
        return {**metrics, **estimate}

    estimates: list[dict] = []
    async for vehicle in db.cars.find({"availability": True}).sort([("order", 1), ("base_price", 1)]):
        estimates.append(calculate_price(
            vehicle, metrics["distance_km"], metrics["duration_hours"],
            payload.trip_type, payload.waypoints,
        ))
    return {**metrics, "trip_type": payload.trip_type, "estimates": estimates}


@router.get("/")
async def list_bookings(
    booking_status: str | None = None,
    current_user: dict = Depends(require_client),
) -> dict:
    user_id = current_user["_id"]
    # Admin can list all bookings; client sees only their own
    if current_user.get("role") == "admin":
        bookings = await list_trips(status=booking_status)
    else:
        bookings = await list_trips(status=booking_status, user_id=user_id)
    return {"bookings": bookings}


@router.get("/history")
async def booking_history(
    current_user: dict = Depends(require_client),
) -> dict:
    return await get_trip_history(user_id=current_user["_id"])


@router.get("/{booking_id}")
async def get_booking(
    booking_id: str,
    current_user: dict = Depends(require_client),
) -> dict:
    db = get_database()
    booking = await db.bookings.find_one({"_id": booking_id})
    if not booking:
        raise HTTPException(status_code=404, detail="Booking not found")
    booking = serialize_document(booking) or {}
    if current_user.get("role") != "admin" and booking.get("user_id") != current_user["_id"]:
        raise HTTPException(status_code=403, detail="Access denied")
    return {"booking": booking}


@router.post("/")
async def create_booking(
    payload: TripCreate,
    current_user: dict = Depends(require_client),
) -> dict:
    data = payload.model_dump()
    data["user_id"] = current_user["_id"]
    data["is_guest"] = False

    # Enforce minimum booking hours
    db = get_database()
    rules_doc = await db.pricing_rules.find_one({"_id": "active"})
    min_hours = (rules_doc or {}).get("minimum_booking_hours", 3)
    _check_time_rule(
        {"departure_date": data.get("departure_date"), "departure_time": data.get("departure_time")},
        min_hours,
        "Booking",
    )

    # Referral credit is a wallet balance, applied automatically — the client
    # never types a code for it. Drawn down BEFORE the booking is written so
    # the stored total is the amount actually owed.
    from app.services.rewards_service import redeem_referral_credits

    credits_applied = await redeem_referral_credits(
        current_user["_id"], float(data.get("total_price") or 0)
    )
    if credits_applied > 0:
        data["credits_used"] = credits_applied
        data["total_price"] = round(
            float(data.get("total_price") or 0) - credits_applied, 2)

    # create_trip emits the single "Booking received / pending confirmation"
    # notification, so no extra push is needed here.
    booking = await create_trip(data)

    # Count the promo redemption once, at booking time (not during validation).
    promo_code = (data.get("promo_code") or "").strip().upper()
    if promo_code:
        await db.promotions.update_one(
            {"code": promo_code},
            {
                "$inc": {"usage_count": 1},
                "$set": {"updated_at": datetime.now(timezone.utc)},
            },
        )

    return {"booking": booking, "credits_applied": credits_applied}


@router.put("/{booking_id}")
async def modify_booking(
    booking_id: str,
    payload: TripUpdate,
    current_user: dict = Depends(require_client),
) -> dict:
    db = get_database()
    booking = await db.bookings.find_one({"_id": booking_id})
    if not booking:
        raise HTTPException(status_code=404, detail="Booking not found")
    booking = serialize_document(booking) or {}

    if current_user.get("role") != "admin" and booking.get("user_id") != current_user["_id"]:
        raise HTTPException(status_code=403, detail="Access denied")

    # Only enforce the modification time-window for clients, not admins
    if current_user.get("role") != "admin":
        rules = await get_pricing_rules()
        _check_time_rule(booking, rules["modification_limit_hours"], "Modification")

    # Validate status when provided
    if payload.status is not None and payload.status not in VALID_STATUSES:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid status '{payload.status}'. Must be one of: {', '.join(sorted(VALID_STATUSES))}",
        )

    updated = await update_trip(booking_id, payload.model_dump())
    if not updated:
        raise HTTPException(status_code=404, detail="Booking not found")

    # Push a status-change notification when admin explicitly sets a new status
    if payload.status is not None and booking.get("user_id"):
        await _push_notification(
            user_id=booking["user_id"],
            title="Booking Update",
            message=f"Your booking status has been updated to: {payload.status.replace('_', ' ').title()}.",
            notif_type="status_update",
            booking_id=booking_id,
        )
    return {"booking": updated}


@router.patch("/{booking_id}/cancel")
async def cancel_booking(
    booking_id: str,
    current_user: dict = Depends(require_client),
) -> dict:
    db = get_database()
    booking = await db.bookings.find_one({"_id": booking_id})
    if not booking:
        raise HTTPException(status_code=404, detail="Booking not found")
    booking = serialize_document(booking) or {}

    if current_user.get("role") != "admin" and booking.get("user_id") != current_user["_id"]:
        raise HTTPException(status_code=403, detail="Access denied")

    if booking.get("status") in ("completed", "cancelled"):
        raise HTTPException(status_code=400, detail="Booking is already completed or cancelled")

    rules = await get_pricing_rules()
    _check_time_rule(booking, rules["cancellation_limit_hours"], "Cancellation")

    # update_trip_status emits the single "Booking cancelled" notification.
    updated = await update_trip_status(booking_id, "cancelled")
    return {"booking": updated}


# ─── Admin-only booking management ─────────────────────────────────────────────

@router.patch("/{booking_id}/status")
async def admin_update_status(
    booking_id: str,
    payload: TripStatusUpdate,
    _: dict = Depends(require_admin),
) -> dict:
    if payload.status not in VALID_STATUSES:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid status. Must be one of: {', '.join(VALID_STATUSES)}",
        )
    # update_trip_status pushes a single, well-worded status notification
    # (see _STATUS_MESSAGES in booking_service); no extra push needed here.
    booking = await update_trip_status(booking_id, payload.status)
    if not booking:
        raise HTTPException(status_code=404, detail="Booking not found")
    return {"booking": booking}


@router.delete("/{booking_id}")
async def admin_delete_booking(
    booking_id: str,
    _: dict = Depends(require_admin),
) -> dict:
    deleted = await delete_trip(booking_id)
    if not deleted:
        raise HTTPException(status_code=404, detail="Booking not found")
    return {"deleted": True}


# ─── Internal helper ───────────────────────────────────────────────────────────

async def _push_notification(
    user_id: str,
    title: str,
    message: str,
    notif_type: str,
    booking_id: str | None = None,
) -> None:
    if not user_id:
        return
    from uuid import uuid4
    db = get_database()
    await db.notifications.insert_one({
        "_id": f"notif-{uuid4().hex}",
        "user_id": user_id,
        "title": title,
        "message": message,
        "type": notif_type,
        "booking_id": booking_id,
        "read": False,
        "created_at": datetime.now(timezone.utc),
    })
