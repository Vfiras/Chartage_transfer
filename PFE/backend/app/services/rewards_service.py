"""Loyalty tiers, auto-generated tier promo codes, and the referral program.

Design notes
------------
* Points stay **derived**, not stored: ``completed bookings x 10``. There is no
  ledger to drift out of sync with the bookings collection.
* Tier promo codes are **generated on read**. ``GET /rewards/me`` asks for the
  user's current tier code; if none exists (new user, new cycle, or a tier
  upgrade) one is minted and stored in ``promotions`` like any other promo, so
  the existing validation path at booking time needs no special-casing.
* Each generated code carries ``owner_user_id`` so it is private to that user.
  Codes without that field are global (e.g. the seeded WELCOME10).
"""
from __future__ import annotations

import random
import string
from datetime import datetime, timedelta, timezone
from uuid import uuid4

from app.core.database import get_database

# name, min_points, next_threshold, next_name
_TIERS: list[tuple[str, int, int | None, str | None]] = [
    ("Bronze", 0, 30, "Silver"),
    ("Silver", 30, 100, "Gold"),
    ("Gold", 100, 200, "Black"),
    ("Black", 200, None, None),
]

POINTS_PER_TRIP = 10

# discount %, uses per code, months the code stays valid
_TIER_PERKS: dict[str, dict] = {
    "Bronze": {"discount": 5, "usage_limit": 3, "cycle_months": 3},
    "Silver": {"discount": 10, "usage_limit": 3, "cycle_months": 3},
    "Gold": {"discount": 15, "usage_limit": 5, "cycle_months": 2},
    # 0 == unlimited, matching the promo validator's existing convention.
    "Black": {"discount": 20, "usage_limit": 0, "cycle_months": 1},
}

REFERRAL_REWARD_EUR = 5.0

_ALPHABET = string.ascii_uppercase + string.digits


def resolve_tier(points: int) -> tuple[str, str | None, int | None]:
    """-> (tier, next_tier, next_tier_threshold)."""
    for name, _low, high, next_name in _TIERS:
        if high is None or points < high:
            return name, next_name, high
    return "Black", None, None


def _rand(n: int = 4) -> str:
    return "".join(random.choices(_ALPHABET, k=n))


def _cycle_key(now: datetime, cycle_months: int) -> str:
    """Stable id for the current refresh window.

    Buckets the year into fixed blocks of ``cycle_months`` so every user on a
    tier shares the same window boundaries and a code cannot be re-minted early
    just because the user checked their rewards on a different day.
    """
    block = (now.month - 1) // cycle_months
    return f"{now.year % 100:02d}{block:d}{cycle_months:d}"


def generate_referral_code(full_name: str) -> str:
    """CT-<first 4 letters of name>-<random 4>, e.g. CT-FIRA-8K2M."""
    letters = "".join(ch for ch in (full_name or "") if ch.isalpha()).upper()
    stem = (letters[:4] or "USER").ljust(4, "X")
    return f"CT-{stem}-{_rand()}"


async def ensure_referral_code(user: dict) -> str:
    """Return the user's referral code, creating one if this is their first read.

    Backfills users created before the referral program existed.
    """
    existing = (user or {}).get("referral_code")
    if existing:
        return str(existing)

    db = get_database()
    code = generate_referral_code(user.get("full_name", ""))
    # Vanishingly unlikely, but a collision would let two users share a code.
    while await db.users.find_one({"referral_code": code}):
        code = generate_referral_code(user.get("full_name", ""))
    await db.users.update_one(
        {"_id": user["_id"]}, {"$set": {"referral_code": code}}
    )
    return code


async def ensure_tier_promo(user_id: str, tier: str) -> dict | None:
    """Return this user's promo for the current tier + cycle, minting if absent."""
    perks = _TIER_PERKS.get(tier)
    if not perks:
        return None

    db = get_database()
    now = datetime.now(timezone.utc)
    cycle = _cycle_key(now, perks["cycle_months"])
    code = f"{tier.upper()}{cycle}-{{rand}}"

    # One active code per (user, tier, cycle).
    existing = await db.promotions.find_one(
        {"owner_user_id": user_id, "tier": tier, "cycle": cycle}
    )
    if existing:
        return existing

    expiry = now + timedelta(days=31 * perks["cycle_months"])
    doc = {
        "_id": f"promo-{uuid4().hex}",
        "code": code.format(rand=_rand()),
        "discount_type": "percentage",
        "value": float(perks["discount"]),
        "expiry_date": expiry.isoformat(),
        "usage_limit": perks["usage_limit"],
        "usage_count": 0,
        "active": True,
        "owner_user_id": user_id,
        "tier": tier,
        "cycle": cycle,
        "created_at": now,
        "updated_at": now,
    }
    await db.promotions.insert_one(doc)
    return doc


async def grant_welcome_promo(user_id: str) -> dict:
    """One-time 10% welcome code, issued per user at signup."""
    db = get_database()
    now = datetime.now(timezone.utc)
    doc = {
        "_id": f"promo-{uuid4().hex}",
        "code": f"WELCOME10-{_rand()}",
        "discount_type": "percentage",
        "value": 10.0,
        "expiry_date": None,
        "usage_limit": 1,
        "usage_count": 0,
        "active": True,
        "owner_user_id": user_id,
        "welcome": True,
        "created_at": now,
        "updated_at": now,
    }
    await db.promotions.insert_one(doc)
    return doc


async def visible_promos(user_id: str) -> list[dict]:
    """Active promos this user may use: their own + global ones.

    A code whose usage limit is spent is filtered out, so a fully-used welcome
    offer stops being advertised.
    """
    db = get_database()
    out: list[dict] = []
    query = {
        "active": True,
        "$or": [{"owner_user_id": user_id}, {"owner_user_id": {"$exists": False}}],
    }
    async for promo in db.promotions.find(query).sort([("value", -1)]):
        limit = promo.get("usage_limit") or 0
        used = promo.get("usage_count") or 0
        if limit and used >= limit:
            continue  # spent
        out.append(promo)
    return out


async def apply_referral(new_user_id: str, referral_code: str) -> dict:
    """Attach a referrer to a new account. Credit is paid on their first ride."""
    db = get_database()
    code = (referral_code or "").strip().upper()
    if not code:
        return {"ok": False, "detail": "Referral code is required."}

    referrer = await db.users.find_one({"referral_code": code})
    if not referrer:
        return {"ok": False, "detail": "That referral code was not found."}
    if referrer["_id"] == new_user_id:
        return {"ok": False, "detail": "You cannot use your own referral code."}

    new_user = await db.users.find_one({"_id": new_user_id})
    if (new_user or {}).get("referred_by"):
        return {"ok": False, "detail": "A referral code has already been applied."}

    await db.users.update_one(
        {"_id": new_user_id},
        {"$set": {"referred_by": referrer["_id"], "referral_pending": True}},
    )
    return {"ok": True, "detail": f"Referral applied. {referrer.get('full_name', 'Your friend')} earns "
                                 f"{REFERRAL_REWARD_EUR:.0f} EUR after your first ride."}


async def settle_referral_if_first_ride(user_id: str) -> None:
    """Pay the referrer once the referred user completes their first booking.

    Called from the booking status transition to ``completed``; safe to call
    repeatedly because ``referral_pending`` is cleared on the first payout.
    """
    db = get_database()
    user = await db.users.find_one({"_id": user_id})
    if not user or not user.get("referral_pending") or not user.get("referred_by"):
        return

    completed = await db.bookings.count_documents(
        {"user_id": user_id, "status": "completed"}
    )
    if completed < 1:
        return

    await db.users.update_one(
        {"_id": user["referred_by"]},
        {"$inc": {"referral_credits": REFERRAL_REWARD_EUR}},
    )
    await db.users.update_one(
        {"_id": user_id}, {"$set": {"referral_pending": False}}
    )
