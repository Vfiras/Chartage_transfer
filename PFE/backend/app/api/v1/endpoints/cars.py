from datetime import datetime, timezone
from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException

from app.core.database import get_database
from app.core.deps import require_admin
from app.db.fleet_data import REAL_FLEET, VALID_CATEGORIES
from app.schemas.dtos import CarCreate, CarUpdate
from app.services.utils import serialize_document

router = APIRouter()


async def _ensure_default_cars() -> None:
    """Bootstrap an empty cars collection with the real fleet (db/fleet_data.py)."""
    db = get_database()
    count = await db.cars.count_documents({})
    if count == 0:
        now = datetime.now(timezone.utc)
        for car in REAL_FLEET:
            await db.cars.insert_one({**car, "created_at": now, "updated_at": now})


# ─── Public ────────────────────────────────────────────────────────────────────

@router.get("/")
async def list_cars() -> dict:
    db = get_database()
    await _ensure_default_cars()
    cars: list[dict] = []
    async for car in db.cars.find({"availability": True}).sort([("base_price", 1)]):
        cars.append(serialize_document(car) or {})
    return {"cars": cars}


@router.get("/all")
async def list_all_cars(_: dict = Depends(require_admin)) -> dict:
    db = get_database()
    await _ensure_default_cars()
    cars: list[dict] = []
    async for car in db.cars.find({}).sort([("base_price", 1)]):
        cars.append(serialize_document(car) or {})
    return {"cars": cars}


# ─── Admin CRUD ────────────────────────────────────────────────────────────────

@router.post("/")
async def create_car(
    payload: CarCreate,
    _: dict = Depends(require_admin),
) -> dict:
    if payload.category not in VALID_CATEGORIES:
        raise HTTPException(status_code=400, detail=f"Category must be one of: {', '.join(VALID_CATEGORIES)}")
    now = datetime.now(timezone.utc)
    document = {
        "_id": f"car-{uuid4().hex}",
        **payload.model_dump(),
        "created_at": now,
        "updated_at": now,
    }
    db = get_database()
    await db.cars.insert_one(document)
    return {"car": serialize_document(document)}


@router.put("/{car_id}")
async def update_car(
    car_id: str,
    payload: CarUpdate,
    _: dict = Depends(require_admin),
) -> dict:
    db = get_database()
    update = {k: v for k, v in payload.model_dump().items() if v is not None}
    if not update:
        raise HTTPException(status_code=400, detail="No fields to update")
    if "category" in update and update["category"] not in VALID_CATEGORIES:
        raise HTTPException(status_code=400, detail=f"Category must be one of: {', '.join(VALID_CATEGORIES)}")

    existing = await db.cars.find_one({"_id": car_id})
    if not existing:
        raise HTTPException(status_code=404, detail="Car not found")

    now = datetime.now(timezone.utc)
    # Record pricing changes so analytics can correlate them with booking
    # volume (analytics_service.get_pricing_impact_analysis).
    if "pricing" in update:
        old_pricing = existing.get("pricing") or {}
        new_pricing = update["pricing"] or {}
        if old_pricing != new_pricing:
            await db.pricing_history.insert_one({
                "_id": f"pricehist-{uuid4().hex}",
                "car_id": car_id,
                "vehicle_name": existing.get("name", car_id),
                "old_initial_fee": old_pricing.get("initial_fee"),
                "new_initial_fee": new_pricing.get("initial_fee"),
                "old_pricing": old_pricing,
                "new_pricing": new_pricing,
                "changed_at": now,
            })

    update["updated_at"] = now
    await db.cars.update_one({"_id": car_id}, {"$set": update})
    car = await db.cars.find_one({"_id": car_id})
    return {"car": serialize_document(car)}


@router.patch("/{car_id}/availability")
async def toggle_availability(
    car_id: str,
    available: bool,
    _: dict = Depends(require_admin),
) -> dict:
    db = get_database()
    result = await db.cars.update_one(
        {"_id": car_id},
        {"$set": {"availability": available, "updated_at": datetime.now(timezone.utc)}},
    )
    if result.matched_count == 0:
        raise HTTPException(status_code=404, detail="Car not found")
    car = await db.cars.find_one({"_id": car_id})
    return {"car": serialize_document(car)}


@router.delete("/{car_id}")
async def delete_car(
    car_id: str,
    _: dict = Depends(require_admin),
) -> dict:
    db = get_database()
    result = await db.cars.delete_one({"_id": car_id})
    if result.deleted_count == 0:
        raise HTTPException(status_code=404, detail="Car not found")
    return {"deleted": True}
