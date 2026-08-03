from datetime import datetime, timezone
from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException

from app.core.database import get_database
from app.core.deps import require_admin
from app.schemas.dtos import PromotionCreate, PromotionUpdate
from app.services.utils import serialize_document

router = APIRouter()


def _classify(promo: dict) -> str:
    """'campaign' = global marketing code; 'member' = minted for one user."""
    return "member" if promo.get("owner_user_id") else "campaign"


@router.get("/")
async def list_promotions(
    scope: str = "all",
    _: dict = Depends(require_admin),
) -> dict:
    """List promo codes.

    scope: 'all' | 'campaign' (global codes the admin owns) | 'member'
    (tier/welcome/referral codes minted for a single client).

    Member codes are resolved to their owner's name so the admin can see who a
    private code belongs to instead of a bare owner_user_id.
    """
    db = get_database()
    query: dict = {}
    if scope == "campaign":
        query = {"owner_user_id": {"$exists": False}}
    elif scope == "member":
        query = {"owner_user_id": {"$exists": True}}

    raw: list[dict] = []
    async for promo in db.promotions.find(query).sort([("created_at", -1)]):
        raw.append(promo)

    # One lookup for every owner referenced, rather than a query per code.
    owner_ids = {p["owner_user_id"] for p in raw if p.get("owner_user_id")}
    owners: dict[str, dict] = {}
    if owner_ids:
        async for user in db.users.find({"_id": {"$in": list(owner_ids)}}):
            owners[user["_id"]] = user

    promos: list[dict] = []
    for promo in raw:
        doc = serialize_document(promo) or {}
        doc["scope"] = _classify(promo)
        owner = owners.get(promo.get("owner_user_id") or "")
        if owner:
            doc["owner_name"] = owner.get("full_name") or owner.get("email", "")
            doc["owner_email"] = owner.get("email", "")
        elif doc["scope"] == "member":
            doc["owner_name"] = "Deleted account"
        # Why this code exists, for the admin's benefit.
        doc["origin"] = (
            "tier" if promo.get("tier")
            else "referral" if promo.get("referral_reward")
            else "welcome" if promo.get("welcome")
            else "campaign"
        )
        promos.append(doc)

    return {"promotions": promos, "scope": scope}


@router.get("/loyalty")
async def loyalty(_: dict = Depends(require_admin)) -> dict:
    """Programme-wide loyalty state — tier spread, members, referral counts."""
    from app.services.rewards_service import loyalty_overview

    return await loyalty_overview()


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
    # A member's tier/welcome/referral code is generated from the loyalty rules.
    # Editing its code or value here would desync it from the tier that minted
    # it, so only toggle (suspend) and delete (revoke) are allowed on those.
    target = await db.promotions.find_one({"_id": promo_id})
    if target and target.get("owner_user_id"):
        raise HTTPException(
            status_code=409,
            detail="This is a member reward code issued by the loyalty "
                   "programme. It can be suspended or revoked, but not edited.",
        )
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
