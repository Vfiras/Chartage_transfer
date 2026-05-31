from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status

from app.core.database import get_database
from app.core.deps import require_admin, require_client
from app.schemas.dtos import TripCreate, TripStatusUpdate, TripUpdate
from app.services.booking_service import (
    create_trip,
    delete_trip,
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


async def _get_pricing_rules() -> dict:
    db = get_database()
    doc = await db.pricing_rules.find_one({"_id": "active"})
    if doc:
        return doc
    return {"modification_limit_hours": 24, "cancellation_limit_hours": 24}


# ─── Client endpoints ──────────────────────────────────────────────────────────

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

    booking = await create_trip(data)
    # Create confirmation notification
    await _push_notification(
        user_id=current_user["_id"],
        title="Booking Confirmed",
        message=f"Your transfer to {data.get('destination_name', 'your destination')} has been received.",
        notif_type="booking_confirmed",
        booking_id=booking.get("_id"),
    )
    return {"booking": booking}


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
        rules = await _get_pricing_rules()
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

    rules = await _get_pricing_rules()
    _check_time_rule(booking, rules["cancellation_limit_hours"], "Cancellation")

    updated = await update_trip_status(booking_id, "cancelled")
    await _push_notification(
        user_id=booking.get("user_id", ""),
        title="Booking Cancelled",
        message="Your booking has been cancelled.",
        notif_type="booking_cancelled",
        booking_id=booking_id,
    )
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
    booking = await update_trip_status(booking_id, payload.status)
    if not booking:
        raise HTTPException(status_code=404, detail="Booking not found")

    if booking.get("user_id"):
        await _push_notification(
            user_id=booking["user_id"],
            title="Booking Update",
            message=f"Your booking status has changed to: {payload.status.replace('_', ' ').title()}.",
            notif_type="status_update",
            booking_id=booking_id,
        )
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
