from datetime import datetime, timezone
from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException

from app.core.database import get_database
from app.core.deps import require_admin
from app.schemas.dtos import PromotionCreate, PromotionUpdate
from app.services.utils import serialize_document

router = APIRouter()


@router.get("/")
async def list_promotions(_: dict = Depends(require_admin)) -> dict:
    db = get_database()
    promos: list[dict] = []
    async for promo in db.promotions.find({}).sort([("created_at", -1)]):
        promos.append(serialize_document(promo) or {})
    return {"promotions": promos}


@router.post("/")
async def create_promotion(
    payload: PromotionCreate,
    _: dict = Depends(require_admin),
) -> dict:
    db = get_database()
    code = payload.code.strip().upper()
    existing = await db.promotions.find_one({"code": code})
    if existing:
        raise HTTPException(status_code=409, detail="Promo code already exists")
    now = datetime.now(timezone.utc)
    document = {
        "_id": f"promo-{uuid4().hex}",
        "code": code,
        "discount_type": payload.discount_type,
        "value": payload.value,
        "expiry_date": payload.expiry_date,
        "usage_limit": payload.usage_limit,
        "usage_count": 0,
        "active": payload.active,
        "created_at": now,
        "updated_at": now,
    }
    await db.promotions.insert_one(document)
    return {"promotion": serialize_document(document)}


@router.put("/{promo_id}")
async def update_promotion(
    promo_id: str,
    payload: PromotionUpdate,
    _: dict = Depends(require_admin),
) -> dict:
    db = get_database()
    update = {k: v for k, v in payload.model_dump().items() if v is not None}
    if not update:
        raise HTTPException(status_code=400, detail="No fields to update")
    if "code" in update:
        update["code"] = update["code"].strip().upper()
    update["updated_at"] = datetime.now(timezone.utc)
    result = await db.promotions.update_one({"_id": promo_id}, {"$set": update})
    if result.matched_count == 0:
        raise HTTPException(status_code=404, detail="Promotion not found")
    promo = await db.promotions.find_one({"_id": promo_id})
    return {"promotion": serialize_document(promo)}


@router.patch("/{promo_id}/toggle")
async def toggle_promotion(
    promo_id: str,
    _: dict = Depends(require_admin),
) -> dict:
    db = get_database()
    promo = await db.promotions.find_one({"_id": promo_id})
    if not promo:
        raise HTTPException(status_code=404, detail="Promotion not found")
    new_state = not promo.get("active", True)
    await db.promotions.update_one(
        {"_id": promo_id},
        {"$set": {"active": new_state, "updated_at": datetime.now(timezone.utc)}},
    )
    promo["active"] = new_state
    return {"promotion": serialize_document(promo)}


@router.delete("/{promo_id}")
async def delete_promotion(
    promo_id: str,
    _: dict = Depends(require_admin),
) -> dict:
    db = get_database()
    result = await db.promotions.delete_one({"_id": promo_id})
    if result.deleted_count == 0:
        raise HTTPException(status_code=404, detail="Promotion not found")
    return {"deleted": True}
