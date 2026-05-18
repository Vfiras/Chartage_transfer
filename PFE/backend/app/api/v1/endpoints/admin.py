from fastapi import APIRouter, Depends

from app.core.deps import require_admin
from app.core.database import get_database
from app.db.seed import seed_database
from app.services.booking_service import list_trips
from app.services.utils import serialize_document

router = APIRouter()


@router.get("/overview")
async def overview(admin: dict = Depends(require_admin)) -> dict:
    db = get_database()
    total_bookings = await db.bookings.count_documents({})
    total_users = await db.users.count_documents({"role": "client"})
    total_cars = await db.cars.count_documents({})
    pending = await db.bookings.count_documents({"status": "pending"})
    confirmed = await db.bookings.count_documents({"status": "confirmed"})
    completed = await db.bookings.count_documents({"status": "completed"})
    cancelled = await db.bookings.count_documents({"status": "cancelled"})

    return {
        "admin": admin.get("full_name", "Admin"),
        "stats": {
            "total_bookings": total_bookings,
            "total_users": total_users,
            "total_cars": total_cars,
            "pending_bookings": pending,
            "confirmed_bookings": confirmed,
            "completed_bookings": completed,
            "cancelled_bookings": cancelled,
        },
    }


@router.get("/bookings")
async def list_all_bookings(
    booking_status: str | None = None,
    _: dict = Depends(require_admin),
) -> dict:
    bookings = await list_trips(status=booking_status)
    return {"bookings": bookings}


@router.get("/users")
async def list_users(_: dict = Depends(require_admin)) -> dict:
    db = get_database()
    users: list[dict] = []
    async for user in db.users.find({"role": "client"}).sort([("created_at", -1)]):
        doc = serialize_document(user) or {}
        doc.pop("hashed_password", None)
        users.append(doc)
    return {"users": users}


@router.post("/seed")
async def run_seed(_: dict = Depends(require_admin)) -> dict:
    result = await seed_database()
    return {"seeded": result}
