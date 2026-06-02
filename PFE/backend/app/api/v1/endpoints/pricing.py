from datetime import datetime, timezone

from fastapi import APIRouter, Depends

from app.core.database import get_database
from app.core.deps import require_admin
from app.schemas.dtos import PricingRulesUpdate, PromoValidationRequest

router = APIRouter()


DEFAULT_PRICING_CONFIG = {
    "minimum_booking_hours": 3,
    "modification_limit_hours": 24,
    "cancellation_limit_hours": 24,
    "night_pricing": {
        "enabled": True,
        "start_time": "22:00",
        "end_time": "06:00",
        "percentage": 30,
    },
    "last_minute_pricing": {
        "enabled": True,
        "within_hours": 24,
        "percentage": 20,
    },
    "weekend_pricing": {
        "enabled": True,
        "percentage": 10,
    },
    "seasonal_pricing": {
        "enabled": False,
        "percentage": 0,
        "label": "Seasonal demand",
    },
}

DEFAULT_PROMOS = {
    "WELCOME10": {"discount_type": "percentage", "value": 10, "active": True},
    "CDHC5": {"discount_type": "percentage", "value": 5, "active": True},
    "CDHC10": {"discount_type": "percentage", "value": 10, "active": True},
}


def _parse_expiry(raw: object) -> datetime | None:
    """Parse a promo `expiry_date` (ISO string or datetime) to a tz-aware UTC datetime."""
    if isinstance(raw, datetime):
        return raw if raw.tzinfo else raw.replace(tzinfo=timezone.utc)
    if isinstance(raw, str) and raw.strip():
        try:
            dt = datetime.fromisoformat(raw.strip().replace("Z", "+00:00"))
            return dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)
        except ValueError:
            return None
    return None


async def _pricing_config() -> dict:
    # Single source of truth: the `pricing_rules` collection (also used by the
    # booking service, the admin PUT /rules write, and the DB seed). Reading the
    # same collection that admins write to keeps config edits in sync.
    db = get_database()
    document = await db.pricing_rules.find_one({"_id": "active"})
    if not document:
        return DEFAULT_PRICING_CONFIG
    config = dict(DEFAULT_PRICING_CONFIG)
    config.update({key: value for key, value in document.items() if key != "_id"})
    return config


@router.get("/config")
async def config() -> dict:
    return {"pricing_config": await _pricing_config()}


@router.post("/promo/validate")
async def validate_promo(payload: PromoValidationRequest) -> dict:
    code = payload.code.strip().upper()
    db = get_database()
    promo = await db.promotions.find_one({"code": code})
    if not promo:
        promo = DEFAULT_PROMOS.get(code)
    if not promo or not promo.get("active", True):
        return {
            "valid": False,
            "code": code,
            "discount": 0,
            "message": "Promo code is not valid.",
        }

    # Expiry — promotions store `expiry_date` as an ISO date/datetime string.
    expiry_dt = _parse_expiry(promo.get("expiry_date"))
    if expiry_dt is not None and expiry_dt < datetime.now(timezone.utc):
        return {
            "valid": False,
            "code": code,
            "discount": 0,
            "message": "Promo code has expired.",
        }

    # Usage limit — reject once the configured number of redemptions is reached.
    usage_limit = promo.get("usage_limit") or 0
    usage_count = promo.get("usage_count") or 0
    if usage_limit and usage_count >= usage_limit:
        return {
            "valid": False,
            "code": code,
            "discount": 0,
            "message": "Promo code usage limit reached.",
        }

    discount_type = promo.get("discount_type", "percentage")
    value = float(promo.get("value", 0))
    discount = payload.subtotal * (value / 100) if discount_type == "percentage" else value
    discount = max(0, min(payload.subtotal, discount))
    return {
        "valid": discount > 0,
        "code": code,
        "discount": round(discount, 2),
        "message": "Promo applied." if discount > 0 else "Promo code is not valid.",
    }


@router.put("/rules")
async def update_pricing_rules(
    payload: PricingRulesUpdate,
    _: dict = Depends(require_admin),
) -> dict:
    db = get_database()
    update = {k: v for k, v in payload.model_dump().items() if v is not None}
    # Flatten nested Pydantic models
    for key, val in list(update.items()):
        if hasattr(val, "model_dump"):
            update[key] = val.model_dump()
    update["updated_at"] = datetime.now(timezone.utc)
    await db.pricing_rules.update_one(
        {"_id": "active"},
        {"$set": update},
        upsert=True,
    )
    config = await _pricing_config()
    return {"pricing_config": config}
