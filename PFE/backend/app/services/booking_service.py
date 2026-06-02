from datetime import datetime, timezone
from uuid import uuid4

from app.core.database import get_database
from app.services.utils import serialize_document


async def _push_notification(user_id: str, title: str, message: str, booking_id: str | None = None) -> None:
    if not user_id or user_id == "guest":
        return
    db = get_database()
    await db.notifications.insert_one({
        "_id": f"notif-{uuid4().hex}",
        "user_id": user_id,
        "title": title,
        "message": message,
        "type": "booking",
        "booking_id": booking_id,
        "read": False,
        "created_at": datetime.now(timezone.utc),
    })


async def create_trip(payload: dict) -> dict:
    db = get_database()
    booking_id = f"booking-{uuid4().hex}"
    payload = {key: value for key, value in payload.items() if value is not None}
    payload.pop("eta_minutes", None)
    document = {
        "_id": booking_id,
        **payload,
        "booking_status": payload.get("status", "pending"),
        "status": payload.get("status", "pending"),
        "created_at": datetime.now(timezone.utc),
        "updated_at": datetime.now(timezone.utc),
    }
    await db.bookings.insert_one(document)
    user_id = payload.get("user_id", "")
    destination = payload.get("destination_name", "your destination")
    await _push_notification(
        user_id,
        "Booking received",
        f"Your transfer to {destination} has been received and is pending confirmation.",
        booking_id,
    )
    return serialize_document(document) or {}


async def list_trips(
    status: str | None = None,
    driver_id: str | None = None,
    user_id: str | None = None,
    guest_email: str | None = None,
) -> list[dict]:
    db = get_database()
    query: dict = {}
    if status:
        query["status"] = status
    if driver_id:
        query["driver_id"] = driver_id
    if user_id:
        query["user_id"] = user_id
    if guest_email:
        query["guest_email"] = guest_email
    trips: list[dict] = []
    async for trip in db.bookings.find(query).sort([("created_at", -1)]):
        trips.append(serialize_document(trip) or {})
    return trips


async def get_trip_history(user_id: str | None = None, guest_email: str | None = None) -> dict:
    trips = await list_trips(user_id=user_id, guest_email=guest_email)
    past_statuses = {"completed", "cancelled"}
    upcoming = [trip for trip in trips if trip.get("status") not in past_statuses]
    past = [trip for trip in trips if trip.get("status") in past_statuses]
    return {"upcoming": upcoming, "past": past}


async def update_trip(trip_id: str, payload: dict) -> dict | None:
    db = get_database()
    update = {key: value for key, value in payload.items() if value is not None}
    if update:
        update["updated_at"] = datetime.now(timezone.utc)
        await db.bookings.update_one({"_id": trip_id}, {"$set": update})
    trip = await db.bookings.find_one({"_id": trip_id})
    return serialize_document(trip)


_STATUS_MESSAGES: dict[str, tuple[str, str]] = {
    "confirmed": ("Booking confirmed", "Your reservation has been confirmed. We'll be there on time."),
    "on_route": ("Driver on the way", "Your driver is on the way to the pickup location."),
    "completed": ("Transfer completed", "Thank you for travelling with Carthage Transfer. We hope to see you again."),
    "cancelled": ("Booking cancelled", "Your reservation has been cancelled."),
    "assigned": ("Driver assigned", "A driver has been assigned to your transfer."),
}


async def update_trip_status(trip_id: str, status: str) -> dict | None:
    trip = await update_trip(trip_id, {"status": status, "booking_status": status})
    if trip:
        user_id = trip.get("user_id", "")
        if status == "completed" and user_id:
            db = get_database()
            await db.users.update_one(
                {"_id": user_id},
                {"$inc": {"completed_rides_count": 1}, "$set": {"updated_at": datetime.now(timezone.utc)}},
            )
        if status in _STATUS_MESSAGES:
            title, message = _STATUS_MESSAGES[status]
            await _push_notification(user_id, title, message, trip_id)
    return trip


async def delete_trip(trip_id: str) -> bool:
    db = get_database()
    result = await db.bookings.delete_one({"_id": trip_id})
    return result.deleted_count == 1
