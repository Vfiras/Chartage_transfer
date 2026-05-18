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


async def _pricing_config() -> dict:
    db = get_database()
    document = await db.pricing_config.find_one({"_id": "active"})
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

    expires_at = promo.get("expires_at")
    if isinstance(expires_at, datetime) and expires_at < datetime.now(timezone.utc):
        return {
            "valid": False,
            "code": code,
            "discount": 0,
            "message": "Promo code has expired.",
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
