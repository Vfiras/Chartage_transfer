from datetime import datetime, timezone
from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException

from app.core.database import get_database
from app.core.deps import require_admin, require_client
from app.services.utils import serialize_document

router = APIRouter()


@router.get("/")
async def list_notifications(current_user: dict = Depends(require_client)) -> dict:
    db = get_database()
    notifications: list[dict] = []
    async for notif in db.notifications.find({"user_id": current_user["_id"]}).sort([("created_at", -1)]).limit(50):
        notifications.append(serialize_document(notif) or {})
    return {"notifications": notifications}


@router.patch("/{notification_id}/read")
async def mark_as_read(
    notification_id: str,
    current_user: dict = Depends(require_client),
) -> dict:
    db = get_database()
    result = await db.notifications.update_one(
        {"_id": notification_id, "user_id": current_user["_id"]},
        {"$set": {"read": True}},
    )
    if result.matched_count == 0:
        raise HTTPException(status_code=404, detail="Notification not found")
    return {"updated": True}


@router.patch("/read-all")
async def mark_all_read(current_user: dict = Depends(require_client)) -> dict:
    db = get_database()
    await db.notifications.update_many(
        {"user_id": current_user["_id"], "read": False},
        {"$set": {"read": True}},
    )
    return {"updated": True}


@router.post("/")
async def push_notification(
    user_id: str,
    title: str,
    message: str,
    notif_type: str = "info",
    _: dict = Depends(require_admin),
) -> dict:
    db = get_database()
    document = {
        "_id": f"notif-{uuid4().hex}",
        "user_id": user_id,
        "title": title,
        "message": message,
        "type": notif_type,
        "booking_id": None,
        "read": False,
        "created_at": datetime.now(timezone.utc),
    }
    await db.notifications.insert_one(document)
    return {"notification": serialize_document(document)}
