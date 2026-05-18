from app.core.database import get_database


async def ensure_indexes() -> None:
    db = get_database()
    await db.users.create_index("email", unique=True)
    await db.bookings.create_index([("user_id", 1), ("created_at", -1)])
    await db.bookings.create_index([("status", 1), ("created_at", -1)])
    await db.bookings.create_index([("guest_email", 1), ("created_at", -1)])
    await db.favorites.create_index([("user_id", 1), ("created_at", -1)])
    await db.notifications.create_index([("user_id", 1), ("created_at", -1)])
    await db.notifications.create_index([("user_id", 1), ("read", 1)])
    await db.promotions.create_index("code", unique=True)
    await db.destinations.create_index([("city", 1), ("region", 1)])
    await db.cars.create_index([("category", 1), ("availability", 1)])
