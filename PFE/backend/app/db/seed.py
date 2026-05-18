from datetime import datetime, timezone

from app.core.database import get_database
from app.core.security import get_password_hash


async def seed_database() -> dict[str, int]:
    db = get_database()
    now = datetime.now(timezone.utc)

    users = [
        {
            "_id": "user-admin-1",
            "email": "admin@carthage-transfer.tn",
            "full_name": "Carthage Admin",
            "phone": "+216 71 000 000",
            "role": "admin",
            "hashed_password": get_password_hash("admin123"),
            "preferred_language": "en",
            "theme_mode": "dark",
            "is_active": True,
            "created_at": now,
            "updated_at": now,
        },
        {
            "_id": "user-client-1",
            "email": "client@example.com",
            "full_name": "Demo Client",
            "phone": "+216 20 123 456",
            "role": "client",
            "hashed_password": get_password_hash("client123"),
            "preferred_language": "en",
            "theme_mode": "dark",
            "is_active": True,
            "created_at": now,
            "updated_at": now,
        },
    ]

    cars = [
        {
            "_id": "car-standard",
            "name": "Standard",
            "model": "Comfort sedan",
            "category": "Standard",
            "seats": 4,
            "luggage": 2,
            "base_price": 18.0,
            "availability": True,
            "image_url": "assets/images/fleet/Renault-Express-Minivan-Transfers-Tunisia.webp",
            "created_at": now,
            "updated_at": now,
        },
        {
            "_id": "car-vip",
            "name": "VIP",
            "model": "Executive sedan",
            "category": "VIP",
            "seats": 3,
            "luggage": 2,
            "base_price": 28.0,
            "availability": True,
            "image_url": "assets/images/fleet/mercedes-e-class-2024-carthage-transfer.webp",
            "created_at": now,
            "updated_at": now,
        },
        {
            "_id": "car-luxury",
            "name": "Luxury",
            "model": "Premium class",
            "category": "Luxury",
            "seats": 3,
            "luggage": 2,
            "base_price": 40.0,
            "availability": True,
            "image_url": "assets/images/fleet/premium-sedan-2024-carthage-transfer.webp",
            "created_at": now,
            "updated_at": now,
        },
        {
            "_id": "car-van",
            "name": "Van",
            "model": "Premium group van",
            "category": "Van",
            "seats": 7,
            "luggage": 5,
            "base_price": 50.0,
            "availability": True,
            "image_url": "assets/images/fleet/Mercedes-V-Class-Vip-Transfers-Tunisia.webp",
            "created_at": now,
            "updated_at": now,
        },
    ]

    destinations = [
        {
            "_id": "dest-bizerte",
            "name": "Bizerte",
            "city": "Bizerte",
            "region": "North",
            "description": "Seaside destination with scenic views and tourist-friendly stops.",
            "visible": True,
            "created_at": now,
            "updated_at": now,
        },
        {
            "_id": "dest-tunis-medina",
            "name": "Tunis Medina",
            "city": "Tunis",
            "region": "Medina",
            "description": "Historic city center with premium food and activity suggestions.",
            "visible": True,
            "created_at": now,
            "updated_at": now,
        },
        {
            "_id": "dest-hammamet",
            "name": "Hammamet",
            "city": "Hammamet",
            "region": "Nabeul",
            "description": "Popular beach resort town south of Tunis.",
            "visible": True,
            "created_at": now,
            "updated_at": now,
        },
        {
            "_id": "dest-sousse",
            "name": "Sousse",
            "city": "Sousse",
            "region": "Sahel",
            "description": "Major coastal city with a UNESCO-listed medina.",
            "visible": True,
            "created_at": now,
            "updated_at": now,
        },
        {
            "_id": "dest-djerba",
            "name": "Djerba",
            "city": "Djerba",
            "region": "Médenine",
            "description": "Island paradise with beautiful beaches and historic sites.",
            "visible": True,
            "created_at": now,
            "updated_at": now,
        },
    ]

    promotions = [
        {
            "_id": "promo-welcome10",
            "code": "WELCOME10",
            "discount_type": "percentage",
            "value": 10.0,
            "expiry_date": None,
            "usage_limit": 1000,
            "usage_count": 0,
            "active": True,
            "created_at": now,
            "updated_at": now,
        },
        {
            "_id": "promo-vip15",
            "code": "VIP15",
            "discount_type": "percentage",
            "value": 15.0,
            "expiry_date": None,
            "usage_limit": 500,
            "usage_count": 0,
            "active": True,
            "created_at": now,
            "updated_at": now,
        },
    ]

    pricing_rules = {
        "_id": "active",
        "minimum_booking_hours": 3,
        "modification_limit_hours": 24,
        "cancellation_limit_hours": 24,
        "night_pricing": {"enabled": True, "start_time": "22:00", "end_time": "06:00", "percentage": 30},
        "last_minute_pricing": {"enabled": True, "within_hours": 24, "percentage": 20},
        "weekend_pricing": {"enabled": True, "percentage": 10},
        "seasonal_pricing": {"enabled": False, "percentage": 0},
        "updated_at": now,
    }

    # Clear all collections before re-seeding
    for collection in ["users", "cars", "bookings", "destinations", "promotions", "pricing_rules"]:
        await db[collection].delete_many({})

    await db.users.insert_many(users)
    await db.cars.insert_many(cars)
    await db.destinations.insert_many(destinations)
    await db.promotions.insert_many(promotions)
    await db.pricing_rules.insert_one(pricing_rules)

    return {
        "users": len(users),
        "cars": len(cars),
        "destinations": len(destinations),
        "promotions": len(promotions),
        "pricing_rules": 1,
    }
