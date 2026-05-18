from fastapi import APIRouter, Depends

from app.core.database import get_database
from app.core.deps import require_admin

router = APIRouter()


@router.get("/dashboard")
async def dashboard(_: dict = Depends(require_admin)) -> dict:
    db = get_database()

    total_bookings = await db.bookings.count_documents({})
    completed = await db.bookings.count_documents({"status": "completed"})
    cancelled = await db.bookings.count_documents({"status": "cancelled"})
    pending = await db.bookings.count_documents({"status": "pending"})
    confirmed = await db.bookings.count_documents({"status": "confirmed"})
    total_users = await db.users.count_documents({"role": "client"})
    total_cars = await db.cars.count_documents({})

    # Revenue: sum of final_price for completed bookings
    revenue_pipeline = [
        {"$match": {"status": "completed"}},
        {"$group": {"_id": None, "total": {"$sum": "$final_price"}}},
    ]
    revenue_result = await db.bookings.aggregate(revenue_pipeline).to_list(1)
    total_revenue = revenue_result[0]["total"] if revenue_result else 0.0

    # Most booked car
    car_pipeline = [
        {"$match": {"status": {"$in": ["completed", "confirmed", "on_route"]}}},
        {"$group": {"_id": "$vehicle_class", "count": {"$sum": 1}}},
        {"$sort": {"count": -1}},
        {"$limit": 1},
    ]
    car_result = await db.bookings.aggregate(car_pipeline).to_list(1)
    most_booked_car = car_result[0]["_id"] if car_result else "N/A"

    # Most requested destination
    dest_pipeline = [
        {"$group": {"_id": "$destination_name", "count": {"$sum": 1}}},
        {"$sort": {"count": -1}},
        {"$limit": 5},
    ]
    dest_result = await db.bookings.aggregate(dest_pipeline).to_list(5)
    popular_destinations = [{"destination": r["_id"], "count": r["count"]} for r in dest_result if r["_id"]]

    # Bookings per day (last 7 days)
    from datetime import datetime, timedelta, timezone
    week_ago = datetime.now(timezone.utc) - timedelta(days=7)
    daily_pipeline = [
        {"$match": {"created_at": {"$gte": week_ago}}},
        {
            "$group": {
                "_id": {
                    "year": {"$year": "$created_at"},
                    "month": {"$month": "$created_at"},
                    "day": {"$dayOfMonth": "$created_at"},
                },
                "count": {"$sum": 1},
            }
        },
        {"$sort": {"_id.year": 1, "_id.month": 1, "_id.day": 1}},
    ]
    daily_result = await db.bookings.aggregate(daily_pipeline).to_list(7)
    bookings_per_day = [
        {
            "date": f"{r['_id']['year']}-{r['_id']['month']:02d}-{r['_id']['day']:02d}",
            "count": r["count"],
        }
        for r in daily_result
    ]

    # Revenue by car category
    category_revenue_pipeline = [
        {"$match": {"status": "completed"}},
        {"$group": {"_id": "$vehicle_class", "revenue": {"$sum": "$final_price"}, "count": {"$sum": 1}}},
        {"$sort": {"revenue": -1}},
    ]
    category_result = await db.bookings.aggregate(category_revenue_pipeline).to_list(10)
    revenue_by_category = [
        {"category": r["_id"] or "Unknown", "revenue": round(r["revenue"], 2), "count": r["count"]}
        for r in category_result
    ]

    return {
        "booking_stats": {
            "total": total_bookings,
            "completed": completed,
            "cancelled": cancelled,
            "pending": pending,
            "confirmed": confirmed,
        },
        "user_stats": {
            "total_clients": total_users,
            "total_cars": total_cars,
        },
        "revenue": {
            "total": round(total_revenue, 2),
            "by_category": revenue_by_category,
        },
        "most_booked_car": most_booked_car,
        "popular_destinations": popular_destinations,
        "bookings_per_day": bookings_per_day,
    }
