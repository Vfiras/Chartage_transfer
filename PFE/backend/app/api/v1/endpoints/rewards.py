from fastapi import APIRouter, Depends
from pydantic import BaseModel

from app.core.database import get_database
from app.core.deps import get_current_user
from app.services.rewards_service import (
    POINTS_PER_TRIP,
    REFERRAL_REWARD_EUR,
    apply_referral,
    ensure_referral_code,
    ensure_tier_promo,
    resolve_tier,
    visible_promos,
)
from app.services.utils import serialize_document

router = APIRouter()


class ReferralRequest(BaseModel):
    referral_code: str


@router.get("/me")
async def get_my_rewards(current_user: dict = Depends(get_current_user)) -> dict:
    db = get_database()
    uid = current_user["_id"]
    completed_trips = await db.bookings.count_documents(
        {"user_id": uid, "status": "completed"}
    )
    points = completed_trips * POINTS_PER_TRIP
    tier, next_tier, next_threshold = resolve_tier(points)

    # Mint this cycle's tier code if the user doesn't have one yet, then list
    # every promo they may actually use (theirs + global, spent ones filtered).
    tier_promo = await ensure_tier_promo(uid, tier)
    referral_code = await ensure_referral_code(current_user)
    promos = [serialize_document(p) or {} for p in await visible_promos(uid)]

    return {
        "points": points,
        "completed_trips": completed_trips,
        "tier": tier,
        "next_tier": next_tier,
        "next_tier_threshold": next_threshold,
        "tier_promo": serialize_document(tier_promo) if tier_promo else None,
        "promo_codes": promos,
        "referral_code": referral_code,
        "referral_credits": float(current_user.get("referral_credits", 0) or 0),
        "referral_reward": REFERRAL_REWARD_EUR,
    }


@router.get("/available-promos")
async def get_available_promos(
    current_user: dict = Depends(get_current_user),
) -> dict:
    promos = [serialize_document(p) or {} for p in await visible_promos(current_user["_id"])]
    return {"promos": promos}


@router.post("/referral")
async def redeem_referral(
    payload: ReferralRequest,
    current_user: dict = Depends(get_current_user),
) -> dict:
    """Attach a referrer to this account; the credit pays out on the first ride."""
    return await apply_referral(current_user["_id"], payload.referral_code)
