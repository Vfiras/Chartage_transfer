from datetime import datetime, timezone
from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException

from app.core.database import get_database
from app.core.deps import require_admin
from app.schemas.dtos import CarCreate, CarUpdate
from app.services.utils import serialize_document

router = APIRouter()

DEFAULT_CARS = [
    {
        "_id": "car-standard",
        "name": "Standard",
        "model": "Comfort sedan",
        "category": "Standard",
        "seats": 4,
        "luggage": 2,
        "base_price": 18,
        "availability": True,
        "image_url": "assets/images/fleet/Renault-Express-Minivan-Transfers-Tunisia.webp",
    },
    {
        "_id": "car-vip",
        "name": "VIP",
        "model": "Executive sedan",
        "category": "VIP",
        "seats": 3,
        "luggage": 2,
        "base_price": 28,
        "availability": True,
        "image_url": "assets/images/fleet/mercedes-e-class-2024-carthage-transfer.webp",
    },
    {
        "_id": "car-luxury",
        "name": "Luxury",
        "model": "Premium class",
        "category": "Luxury",
        "seats": 3,
        "luggage": 2,
        "base_price": 40,
        "availability": True,
        "image_url": "assets/images/fleet/premium-sedan-2024-carthage-transfer.webp",
    },
    {
        "_id": "car-van",
        "name": "Van",
        "model": "Premium group van",
        "category": "Van",
        "seats": 7,
        "luggage": 5,
        "base_price": 50,
        "availability": True,
        "image_url": "assets/images/fleet/Mercedes-V-Class-Vip-Transfers-Tunisia.webp",
    },
]

VALID_CATEGORIES = {"Standard", "VIP", "Van", "Luxury"}


async def _ensure_default_cars() -> None:
    db = get_database()
    count = await db.cars.count_documents({})
    if count == 0:
        for car in DEFAULT_CARS:
            car["created_at"] = datetime.now(timezone.utc)
            car["updated_at"] = datetime.now(timezone.utc)
            await db.cars.insert_one(dict(car))


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
    update["updated_at"] = datetime.now(timezone.utc)
    result = await db.cars.update_one({"_id": car_id}, {"$set": update})
    if result.matched_count == 0:
        raise HTTPException(status_code=404, detail="Car not found")
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
