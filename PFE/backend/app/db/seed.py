from datetime import datetime, timedelta, timezone

from app.core.database import get_database
from app.core.security import get_password_hash
from app.db.fleet_data import REAL_FLEET


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

    # Real fleet from the live site's Chauffeur Booking System pages, with full
    # per-vehicle pricing parameters (see db/fleet_data.py).
    cars = [{**car, "created_at": now, "updated_at": now} for car in REAL_FLEET]

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

    # Demo bookings — one per status so the admin workflow and the client
    # Trips/Alerts tabs are populated immediately on a fresh seed.
    def _booking(suffix, status, pickup, dest, city, vclass, date, time,
                 pax, bags, price, age_minutes):
        ts = now - timedelta(minutes=age_minutes)
        return {
            "_id": f"booking-demo-{suffix}",
            "user_id": "user-client-1",
            "passenger_name": "Demo Client",
            "passenger_phone": "+216 20 123 456",
            "pickup_location": pickup,
            "destination_name": dest,
            "destination_city": city,
            "vehicle_type": vclass,
            "vehicle_class": vclass,
            "status": status,
            "booking_status": status,
            "trip_type": "one_way",
            "departure_date": date,
            "departure_time": time,
            "passenger_count": pax,
            "luggage_count": bags,
            "total_price": price,
            "is_guest": False,
            "contact_email": "client@example.com",
            "contact_phone": "+216 20 123 456",
            "created_at": ts,
            "updated_at": ts,
        }

    bookings = [
        _booking("pending", "pending", "Tunis-Carthage Airport (TUN)",
                 "Hammamet", "Hammamet", "VIP", "2026-06-02", "14:30",
                 2, 3, 92.0, 5),
        _booking("confirmed", "confirmed", "La Marsa",
                 "Tunis City Centre", "Tunis", "Standard", "2026-06-03", "09:00",
                 1, 1, 26.0, 60),
        _booking("onroute", "on_route", "Sousse",
                 "Monastir Airport (MIR)", "Monastir", "Luxury", "2026-05-22", "16:45",
                 3, 2, 58.0, 180),
        _booking("completed", "completed", "Tunis City Centre",
                 "Sidi Bou Said", "Tunis", "VIP", "2026-05-18", "11:15",
                 2, 1, 34.0, 4320),
        _booking("cancelled", "cancelled", "Nabeul",
                 "Tunis-Carthage Airport (TUN)", "Tunis", "Van", "2026-05-16", "07:30",
                 5, 6, 70.0, 7200),
    ]

    notifications = [
        {
            "_id": "notif-demo-1",
            "user_id": "user-client-1",
            "title": "Booking received",
            "message": "Your transfer to Hammamet has been received and is pending confirmation.",
            "type": "booking",
            "booking_id": "booking-demo-pending",
            "read": False,
            "created_at": now - timedelta(minutes=5),
        },
        {
            "_id": "notif-demo-2",
            "user_id": "user-client-1",
            "title": "Booking confirmed",
            "message": "Your reservation has been confirmed. We'll be there on time.",
            "type": "booking",
            "booking_id": "booking-demo-confirmed",
            "read": False,
            "created_at": now - timedelta(minutes=58),
        },
        {
            "_id": "notif-demo-3",
            "user_id": "user-client-1",
            "title": "Driver on the way",
            "message": "Your driver is on the way to the pickup location.",
            "type": "booking",
            "booking_id": "booking-demo-onroute",
            "read": True,
            "created_at": now - timedelta(minutes=175),
        },
        {
            "_id": "notif-demo-4",
            "user_id": "user-client-1",
            "title": "Transfer completed",
            "message": "Thank you for travelling with Carthage Transfer. We hope to see you again.",
            "type": "booking",
            "booking_id": "booking-demo-completed",
            "read": True,
            "created_at": now - timedelta(days=3),
        },
    ]

    # Clear all collections before re-seeding. The second row are collections
    # that accumulate runtime/test cruft (complaints, chat history, AI audit
    # rows, saved places, pricing-change log) — cleared too so a fresh seed is
    # a genuinely clean, demo-ready state rather than leaving stale test data
    # visible in the admin UI.
    for collection in [
        "users", "cars", "bookings", "destinations",
        "promotions", "pricing_rules", "notifications",
        "complaints", "chat_sessions", "audit_log", "favorites", "pricing_history",
    ]:
        await db[collection].delete_many({})

    await db.users.insert_many(users)
    await db.cars.insert_many(cars)
    await db.destinations.insert_many(destinations)
    await db.promotions.insert_many(promotions)
    await db.pricing_rules.insert_one(pricing_rules)
    await db.bookings.insert_many(bookings)
    await db.notifications.insert_many(notifications)

    return {
        "users": len(users),
        "cars": len(cars),
        "destinations": len(destinations),
        "promotions": len(promotions),
        "pricing_rules": 1,
        "bookings": len(bookings),
        "notifications": len(notifications),
    }
