from datetime import datetime, timezone
from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException

from app.core.database import get_database
from app.core.deps import get_current_user, require_admin
from app.schemas.dtos import ComplaintCreate, ComplaintStatusUpdate
from app.services.utils import serialize_document

router = APIRouter()

VALID_COMPLAINT_STATUSES = {"open", "in_review", "resolved"}


async def create_complaint_record(user_id: str, booking_id: str | None, message: str) -> dict:
    """Shared logic used by the route and the AVA submit_claim tool."""
    now = datetime.now(timezone.utc)
    doc = {
        "_id": f"claim-{uuid4().hex}",
        "user_id": user_id,
        "booking_id": booking_id,
        "message": message,
        "status": "open",
        "created_at": now,
    }
    db = get_database()
    await db.complaints.insert_one(doc)
    return serialize_document(doc) or {}


@router.post("/")
async def submit_complaint(
    payload: ComplaintCreate,
    current_user: dict = Depends(get_current_user),
) -> dict:
    complaint = await create_complaint_record(
        user_id=current_user["_id"],
        booking_id=payload.booking_id,
        message=payload.message,
    )
    return {"complaint": complaint}


@router.get("/")
async def list_complaints(_: dict = Depends(require_admin)) -> dict:
    db = get_database()
    complaints: list[dict] = []
    async for doc in db.complaints.find({}).sort([("created_at", -1)]):
        complaints.append(serialize_document(doc) or {})
    return {"complaints": complaints}


@router.patch("/{complaint_id}/status")
async def update_complaint_status(
    complaint_id: str,
    payload: ComplaintStatusUpdate,
    _: dict = Depends(require_admin),
) -> dict:
    status = payload.status.strip().lower()
    if status not in VALID_COMPLAINT_STATUSES:
        raise HTTPException(
            status_code=400,
            detail=f"Status must be one of: {', '.join(sorted(VALID_COMPLAINT_STATUSES))}",
        )
    db = get_database()
    result = await db.complaints.update_one(
        {"_id": complaint_id},
        {"$set": {"status": status, "updated_at": datetime.now(timezone.utc)}},
    )
    if result.matched_count == 0:
        raise HTTPException(status_code=404, detail="Complaint not found")
    doc = await db.complaints.find_one({"_id": complaint_id})
    return {"complaint": serialize_document(doc) or {}}
