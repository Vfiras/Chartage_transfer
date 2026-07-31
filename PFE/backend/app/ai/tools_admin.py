"""
Admin-facing LangChain tools for the AVA agent.

These tools contain NO user_id or role parameter — they operate on the full
dataset and are only handed to the LLM after role verification in tool_registry.
"""
from __future__ import annotations

import sys, os
_backend_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
if _backend_dir not in sys.path:
    sys.path.insert(0, _backend_dir)

from datetime import datetime, timedelta, timezone
from typing import Optional
from uuid import uuid4

from langchain_core.tools import tool

from app.core.database import get_database
from app.services.booking_service import list_trips, update_trip_status
from app.services.utils import serialize_document

_VALID_CATEGORIES = {"Standard", "VIP", "Luxury", "Van"}
_VALID_STATUSES = {"pending", "confirmed", "on_route", "completed", "cancelled"}


# ── 1. Fleet management ────────────────────────────────────────────────────────

@tool
async def manage_fleet(
    action: str,
    car_id: Optional[str] = None,
    name: Optional[str] = None,
    model: Optional[str] = None,
    category: Optional[str] = None,
    seats: Optional[int] = None,
    luggage: Optional[int] = None,
    base_price: Optional[float] = None,
    availability: Optional[bool] = None,
    image_url: Optional[str] = None,
) -> dict:
    """Manage the vehicle fleet (admin only).
    action: 'list' | 'create' | 'update' | 'toggle_availability' | 'delete'.
    For 'list': no extra params needed.
    For 'create': name, model, category, seats, luggage, base_price required.
    For 'update': car_id required; supply only fields to change.
    For 'toggle_availability': car_id and availability (bool) required.
    For 'delete': car_id required."""
    db = get_database()

    if action == "list":
        cars: list[dict] = []
        async for car in db.cars.find({}).sort([("base_price", 1)]):
            cars.append(serialize_document(car) or {})
        return {"cars": cars}

    elif action == "create":
        missing = [f for f, v in [("name", name), ("model", model), ("category", category),
                                    ("seats", seats), ("luggage", luggage), ("base_price", base_price)]
                   if v is None]
        if missing:
            return {"error": f"create requires: {', '.join(missing)}"}
        if category not in _VALID_CATEGORIES:
            return {"error": f"category must be one of: {', '.join(_VALID_CATEGORIES)}"}
        now = datetime.now(timezone.utc)
        doc = {
            "_id": f"car-{uuid4().hex}",
            "name": name, "model": model, "category": category,
            "seats": seats, "luggage": luggage, "base_price": base_price,
            "availability": True if availability is None else availability,
            "image_url": image_url,
            "created_at": now, "updated_at": now,
        }
        await db.cars.insert_one(doc)
        return {"car": serialize_document(doc)}

    elif action == "update":
        if not car_id:
            return {"error": "update requires car_id"}
        update = {k: v for k, v in {"name": name, "model": model, "category": category,
                                     "seats": seats, "luggage": luggage, "base_price": base_price,
                                     "availability": availability, "image_url": image_url}.items()
                  if v is not None}
        if not update:
            return {"error": "No fields to update"}
        if "category" in update and update["category"] not in _VALID_CATEGORIES:
            return {"error": f"category must be one of: {', '.join(_VALID_CATEGORIES)}"}
        update["updated_at"] = datetime.now(timezone.utc)
        await db.cars.update_one({"_id": car_id}, {"$set": update})
        car = await db.cars.find_one({"_id": car_id})
        return {"car": serialize_document(car) or {"error": "Car not found after update"}}

    elif action == "toggle_availability":
        if car_id is None or availability is None:
            return {"error": "toggle_availability requires car_id and availability (true/false)"}
        await db.cars.update_one(
            {"_id": car_id},
            {"$set": {"availability": availability, "updated_at": datetime.now(timezone.utc)}},
        )
        car = await db.cars.find_one({"_id": car_id})
        return {"car": serialize_document(car) or {"error": "Car not found"}}

    elif action == "delete":
        if not car_id:
            return {"error": "delete requires car_id"}
        result = await db.cars.delete_one({"_id": car_id})
        return {"deleted": result.deleted_count == 1}

    return {"error": f"Unknown action '{action}'. Valid: list, create, update, toggle_availability, delete"}


# ── 2. Pricing rules ───────────────────────────────────────────────────────────

@tool
async def manage_pricing_rules(
    action: str,
    minimum_booking_hours: Optional[int] = None,
    modification_limit_hours: Optional[int] = None,
    cancellation_limit_hours: Optional[int] = None,
    night_enabled: Optional[bool] = None,
    night_start: Optional[str] = None,
    night_end: Optional[str] = None,
    night_percentage: Optional[float] = None,
    last_minute_enabled: Optional[bool] = None,
    last_minute_within_hours: Optional[int] = None,
    last_minute_percentage: Optional[float] = None,
    weekend_enabled: Optional[bool] = None,
    weekend_percentage: Optional[float] = None,
    seasonal_enabled: Optional[bool] = None,
    seasonal_percentage: Optional[float] = None,
    seasonal_label: Optional[str] = None,
) -> dict:
    """Get or update the dynamic pricing rules configuration (admin only).
    action: 'get' to read current config | 'update' to change one or more fields.
    For 'update', supply only the fields you want to change."""
    db = get_database()

    if action == "get":
        doc = await db.pricing_rules.find_one({"_id": "active"})
        return serialize_document(doc) or {"info": "No pricing rules set — defaults apply"}

    elif action == "update":
        update: dict = {}
        if minimum_booking_hours is not None:
            update["minimum_booking_hours"] = minimum_booking_hours
        if modification_limit_hours is not None:
            update["modification_limit_hours"] = modification_limit_hours
        if cancellation_limit_hours is not None:
            update["cancellation_limit_hours"] = cancellation_limit_hours
        if any(v is not None for v in (night_enabled, night_start, night_end, night_percentage)):
            existing = await db.pricing_rules.find_one({"_id": "active"}) or {}
            night = dict(existing.get("night_pricing") or {})
            if night_enabled is not None: night["enabled"] = night_enabled
            if night_start is not None:   night["start_time"] = night_start
            if night_end is not None:     night["end_time"] = night_end
            if night_percentage is not None: night["percentage"] = night_percentage
            update["night_pricing"] = night
        if any(v is not None for v in (last_minute_enabled, last_minute_within_hours, last_minute_percentage)):
            existing = await db.pricing_rules.find_one({"_id": "active"}) or {}
            lm = dict(existing.get("last_minute_pricing") or {})
            if last_minute_enabled is not None:      lm["enabled"] = last_minute_enabled
            if last_minute_within_hours is not None: lm["within_hours"] = last_minute_within_hours
            if last_minute_percentage is not None:   lm["percentage"] = last_minute_percentage
            update["last_minute_pricing"] = lm
        if any(v is not None for v in (weekend_enabled, weekend_percentage)):
            existing = await db.pricing_rules.find_one({"_id": "active"}) or {}
            wk = dict(existing.get("weekend_pricing") or {})
            if weekend_enabled is not None:    wk["enabled"] = weekend_enabled
            if weekend_percentage is not None: wk["percentage"] = weekend_percentage
            update["weekend_pricing"] = wk
        if any(v is not None for v in (seasonal_enabled, seasonal_percentage, seasonal_label)):
            existing = await db.pricing_rules.find_one({"_id": "active"}) or {}
            se = dict(existing.get("seasonal_pricing") or {})
            if seasonal_enabled is not None:    se["enabled"] = seasonal_enabled
            if seasonal_percentage is not None: se["percentage"] = seasonal_percentage
            if seasonal_label is not None:      se["label"] = seasonal_label
            update["seasonal_pricing"] = se
        if not update:
            return {"error": "No fields to update — supply at least one pricing parameter"}
        update["updated_at"] = datetime.now(timezone.utc)
        await db.pricing_rules.update_one({"_id": "active"}, {"$set": update}, upsert=True)
        doc = await db.pricing_rules.find_one({"_id": "active"})
        return {"updated": serialize_document(doc)}

    return {"error": f"Unknown action '{action}'. Valid: get, update"}


# ── 3. Supplier management ─────────────────────────────────────────────────────

@tool
async def manage_suppliers(
    action: str,
    supplier_id: Optional[str] = None,
    name: Optional[str] = None,
    phone: Optional[str] = None,
    email: Optional[str] = None,
    handle: Optional[str] = None,
    status: Optional[str] = None,
) -> dict:
    """Manage transport suppliers / sub-contractors (admin only).
    action: 'list' | 'create' | 'update' | 'update_status' | 'delete'.
    status values: 'active' | 'inactive' | 'suspended'."""
    db = get_database()

    if action == "list":
        suppliers: list[dict] = []
        async for doc in db.suppliers.find({}).sort([("name", 1)]):
            suppliers.append(serialize_document(doc) or {})
        return {"suppliers": suppliers}

    elif action == "create":
        if not name:
            return {"error": "create requires at least: name"}
        now = datetime.now(timezone.utc)
        doc = {
            "_id": f"sup-{uuid4().hex}",
            "name": name, "phone": phone or "", "email": email or "",
            "handle": handle or "", "status": status or "active",
            "created_at": now, "updated_at": now,
        }
        await db.suppliers.insert_one(doc)
        return {"supplier": serialize_document(doc)}

    elif action == "update":
        if not supplier_id:
            return {"error": "update requires supplier_id"}
        update = {k: v for k, v in {"name": name, "phone": phone, "email": email,
                                     "handle": handle, "status": status}.items() if v is not None}
        if not update:
            return {"error": "No fields to update"}
        update["updated_at"] = datetime.now(timezone.utc)
        await db.suppliers.update_one({"_id": supplier_id}, {"$set": update})
        doc = await db.suppliers.find_one({"_id": supplier_id})
        return {"supplier": serialize_document(doc) or {"error": "Not found"}}

    elif action == "update_status":
        if not supplier_id or not status:
            return {"error": "update_status requires supplier_id and status"}
        if status not in ("active", "inactive", "suspended"):
            return {"error": "status must be 'active', 'inactive', or 'suspended'"}
        await db.suppliers.update_one(
            {"_id": supplier_id},
            {"$set": {"status": status, "updated_at": datetime.now(timezone.utc)}},
        )
        doc = await db.suppliers.find_one({"_id": supplier_id})
        return {"supplier": serialize_document(doc) or {"error": "Not found"}}

    elif action == "delete":
        if not supplier_id:
            return {"error": "delete requires supplier_id"}
        result = await db.suppliers.delete_one({"_id": supplier_id})
        return {"deleted": result.deleted_count == 1}

    return {"error": f"Unknown action '{action}'. Valid: list, create, update, update_status, delete"}


# ── 4. Promotion management ────────────────────────────────────────────────────

@tool
async def manage_promotions(
    action: str,
    promo_id: Optional[str] = None,
    code: Optional[str] = None,
    discount_type: Optional[str] = None,
    value: Optional[float] = None,
    expiry_date: Optional[str] = None,
    usage_limit: Optional[int] = None,
    active: Optional[bool] = None,
) -> dict:
    """Manage promotional codes (admin only).
    action: 'list' | 'create' | 'update' | 'toggle' | 'delete'.
    discount_type: 'percentage' | 'fixed'."""
    db = get_database()

    if action == "list":
        promos: list[dict] = []
        async for doc in db.promotions.find({}).sort([("created_at", -1)]):
            promos.append(serialize_document(doc) or {})
        return {"promotions": promos}

    elif action == "create":
        if not code or value is None:
            return {"error": "create requires: code, value"}
        code_upper = code.strip().upper()
        if await db.promotions.find_one({"code": code_upper}):
            return {"error": f"Promo code '{code_upper}' already exists"}
        now = datetime.now(timezone.utc)
        doc = {
            "_id": f"promo-{uuid4().hex}",
            "code": code_upper,
            "discount_type": discount_type or "percentage",
            "value": value,
            "expiry_date": expiry_date,
            "usage_limit": usage_limit or 100,
            "usage_count": 0,
            "active": True if active is None else active,
            "created_at": now, "updated_at": now,
        }
        await db.promotions.insert_one(doc)
        return {"promotion": serialize_document(doc)}

    elif action == "update":
        if not promo_id:
            return {"error": "update requires promo_id"}
        update = {k: v for k, v in {"code": code, "discount_type": discount_type,
                                     "value": value, "expiry_date": expiry_date,
                                     "usage_limit": usage_limit, "active": active}.items()
                  if v is not None}
        if "code" in update:
            update["code"] = update["code"].strip().upper()
        if not update:
            return {"error": "No fields to update"}
        update["updated_at"] = datetime.now(timezone.utc)
        await db.promotions.update_one({"_id": promo_id}, {"$set": update})
        doc = await db.promotions.find_one({"_id": promo_id})
        return {"promotion": serialize_document(doc) or {"error": "Not found"}}

    elif action == "toggle":
        if not promo_id:
            return {"error": "toggle requires promo_id"}
        promo = await db.promotions.find_one({"_id": promo_id})
        if not promo:
            return {"error": "Promotion not found"}
        new_state = not promo.get("active", True)
        await db.promotions.update_one(
            {"_id": promo_id},
            {"$set": {"active": new_state, "updated_at": datetime.now(timezone.utc)}},
        )
        promo["active"] = new_state
        return {"promotion": serialize_document(promo)}

    elif action == "delete":
        if not promo_id:
            return {"error": "delete requires promo_id"}
        result = await db.promotions.delete_one({"_id": promo_id})
        return {"deleted": result.deleted_count == 1}

    return {"error": f"Unknown action '{action}'. Valid: list, create, update, toggle, delete"}


# ── 5. Dashboard analytics ─────────────────────────────────────────────────────

@tool
async def get_dashboard_analytics() -> dict:
    """Return comprehensive analytics for the admin dashboard: booking stats,
    revenue by vehicle category, most booked vehicle, popular destinations,
    and a 7-day daily booking trend."""
    db = get_database()

    total    = await db.bookings.count_documents({})
    completed = await db.bookings.count_documents({"status": "completed"})
    cancelled = await db.bookings.count_documents({"status": "cancelled"})
    pending   = await db.bookings.count_documents({"status": "pending"})
    confirmed = await db.bookings.count_documents({"status": "confirmed"})
    total_users = await db.users.count_documents({"role": "client"})
    total_cars  = await db.cars.count_documents({})

    rev = await db.bookings.aggregate([
        {"$match": {"status": "completed"}},
        {"$group": {"_id": None, "total": {"$sum": "$total_price"}}},
    ]).to_list(1)
    total_revenue = rev[0]["total"] if rev else 0.0

    most_booked = await db.bookings.aggregate([
        {"$match": {"status": {"$in": ["completed", "confirmed", "on_route"]}}},
        {"$group": {"_id": "$vehicle_class", "count": {"$sum": 1}}},
        {"$sort": {"count": -1}}, {"$limit": 1},
    ]).to_list(1)

    dest_res = await db.bookings.aggregate([
        {"$group": {"_id": "$destination_name", "count": {"$sum": 1}}},
        {"$sort": {"count": -1}}, {"$limit": 5},
    ]).to_list(5)

    week_ago = datetime.now(timezone.utc) - timedelta(days=7)
    daily_res = await db.bookings.aggregate([
        {"$match": {"created_at": {"$gte": week_ago}}},
        {"$group": {"_id": {"y": {"$year": "$created_at"},
                             "m": {"$month": "$created_at"},
                             "d": {"$dayOfMonth": "$created_at"}},
                    "count": {"$sum": 1}}},
        {"$sort": {"_id.y": 1, "_id.m": 1, "_id.d": 1}},
    ]).to_list(7)

    cat_rev = await db.bookings.aggregate([
        {"$match": {"status": "completed"}},
        {"$group": {"_id": "$vehicle_class",
                    "revenue": {"$sum": "$total_price"}, "count": {"$sum": 1}}},
        {"$sort": {"revenue": -1}},
    ]).to_list(10)

    return {
        "booking_stats": {"total": total, "completed": completed, "cancelled": cancelled,
                          "pending": pending, "confirmed": confirmed},
        "user_stats": {"total_clients": total_users, "total_cars": total_cars},
        "revenue": {
            "total": round(total_revenue, 2),
            "by_category": [{"category": r["_id"] or "Unknown",
                             "revenue": round(r["revenue"], 2), "count": r["count"]}
                            for r in cat_rev],
        },
        "most_booked_car": most_booked[0]["_id"] if most_booked else "N/A",
        "popular_destinations": [{"destination": r["_id"], "count": r["count"]}
                                  for r in dest_res if r["_id"]],
        "bookings_per_day": [
            {"date": f"{r['_id']['y']}-{r['_id']['m']:02d}-{r['_id']['d']:02d}",
             "count": r["count"]}
            for r in daily_res
        ],
    }


# ── 6. Admin overview ──────────────────────────────────────────────────────────

@tool
async def get_admin_overview() -> dict:
    """Return a concise admin overview: total bookings, users, vehicles, and
    a breakdown of booking counts by status."""
    db = get_database()
    return {
        "stats": {
            "total_bookings":    await db.bookings.count_documents({}),
            "total_users":       await db.users.count_documents({"role": "client"}),
            "total_cars":        await db.cars.count_documents({}),
            "pending_bookings":  await db.bookings.count_documents({"status": "pending"}),
            "confirmed_bookings":await db.bookings.count_documents({"status": "confirmed"}),
            "completed_bookings":await db.bookings.count_documents({"status": "completed"}),
            "cancelled_bookings":await db.bookings.count_documents({"status": "cancelled"}),
        }
    }


# ── 7. List all bookings ───────────────────────────────────────────────────────

@tool
async def list_all_bookings(status_filter: Optional[str] = None) -> dict:
    """List every booking in the system (admin only), optionally filtered by
    status.  status_filter: pending | confirmed | on_route | completed | cancelled"""
    bookings = await list_trips(status=status_filter)
    return {"bookings": bookings, "count": len(bookings)}


# ── 8. List users ──────────────────────────────────────────────────────────────

@tool
async def list_users() -> dict:
    """List all registered client accounts (admin only).
    Passwords are never returned."""
    db = get_database()
    users: list[dict] = []
    async for user in db.users.find({"role": "client"}).sort([("created_at", -1)]):
        doc = serialize_document(user) or {}
        doc.pop("hashed_password", None)
        users.append(doc)
    return {"users": users, "count": len(users)}


# ── 9. Update booking status ───────────────────────────────────────────────────

@tool
async def update_booking_status(booking_id: str, new_status: str) -> dict:
    """Set a booking's status directly (admin only).
    new_status: pending | confirmed | on_route | completed | cancelled"""
    if new_status not in _VALID_STATUSES:
        return {"error": f"Invalid status '{new_status}'. Valid: {', '.join(sorted(_VALID_STATUSES))}"}
    result = await update_trip_status(booking_id, new_status)
    if not result:
        return {"error": f"Booking '{booking_id}' not found"}
    return {"booking": result}


# ── 10. Business intelligence analysis ─────────────────────────────────────────

_ANALYST_PROMPT = (
    "You are a business analyst. Given this data from a Tunisian private "
    "transport company (Carthage Transfer, prices in EUR), identify the 3 most "
    "important insights, explain what's driving them, and rate the business "
    "health (strong / stable / needs attention). Be specific with numbers from "
    "the data. Answer in under 180 words of plain prose — no markdown headers."
)


def _fmt_month(ym: str) -> str:
    """'2026-07' → 'Jul 2026' for chart labels."""
    try:
        return datetime.strptime(ym, "%Y-%m").strftime("%b %Y")
    except ValueError:
        return ym


def _build_charts(analysis_type: str, data: dict) -> list[dict]:
    """Deterministic chart specifications from the raw analytics data.
    Format consumed by the Flutter AnalyticsCard (type/title/data/color_scheme)."""
    charts: list[dict] = []

    revenue = data.get("revenue_by_month") or []
    if revenue and analysis_type in ("full_review", "revenue", "seasonal"):
        peak = max(revenue, key=lambda r: r["revenue"])
        charts.append({
            "type": "line",
            "title": f"Monthly Revenue (Last {len(revenue)} Months)",
            "data": [{"label": _fmt_month(r["month"]), "value": r["revenue"]}
                     for r in revenue],
            "color_scheme": "gold",
            "highlight": _fmt_month(peak["month"]),
        })
        charts.append({
            "type": "bar",
            "title": "Completed Bookings per Month",
            "data": [{"label": _fmt_month(r["month"]), "value": r["booking_count"]}
                     for r in revenue],
            "color_scheme": "gold",
        })

    categories = data.get("revenue_by_category") or []
    if categories and analysis_type in ("full_review", "revenue", "vehicles"):
        charts.append({
            "type": "pie",
            "title": "Revenue by Vehicle Category",
            "data": [{"label": c["category"], "value": c["percentage"]}
                     for c in categories],
            "color_scheme": "mixed",
        })

    volume = data.get("booking_volume") or []
    if volume and analysis_type in ("full_review", "seasonal"):
        charts.append({
            "type": "area",
            "title": "Weekly Booking Volume",
            "data": [{"label": v["period"], "value": v["bookings"]}
                     for v in volume],
            "color_scheme": "blue",
        })

    impact = data.get("pricing_impact") or []
    if impact and analysis_type in ("full_review", "pricing_impact"):
        chart_data: list[dict] = []
        for change in impact[:4]:
            label = f"{change['vehicle'][:14]} {change['change_date'][5:]}"
            chart_data.append({"label": f"{label} (before)",
                               "value": change["bookings_before_7d"]})
            chart_data.append({"label": f"{label} (after)",
                               "value": change["bookings_after_7d"]})
        charts.append({
            "type": "bar",
            "title": "Bookings 7 Days Before vs After Pricing Changes",
            "data": chart_data,
            "color_scheme": "mixed",
        })
    return charts


def _build_kpis(kpi: dict) -> list[dict]:
    def pct(v: float | None) -> str | None:
        return f"{v * 100:+.0f}%" if isinstance(v, (int, float)) else None

    out = [
        {"label": "Revenue MTD", "value": f"€{kpi.get('total_revenue_mtd', 0):,.0f}",
         "trend": pct(kpi.get("revenue_growth_mom")),
         "positive": (kpi.get("revenue_growth_mom") or 0) >= 0},
        {"label": "Revenue YTD", "value": f"€{kpi.get('total_revenue_ytd', 0):,.0f}",
         "trend": pct(kpi.get("revenue_growth_yoy")),
         "positive": (kpi.get("revenue_growth_yoy") or 0) >= 0},
        {"label": "Bookings MTD", "value": str(kpi.get("bookings_mtd", 0)),
         "trend": None, "positive": True},
        {"label": "Avg Booking", "value": f"€{kpi.get('avg_booking_value', 0):,.0f}",
         "trend": None, "positive": True},
    ]
    if kpi.get("top_vehicle"):
        out.append({"label": "Top Vehicle", "value": str(kpi["top_vehicle"]),
                    "trend": None, "positive": True})
    return out


def _deterministic_insights(data: dict) -> list[str]:
    """Fallback insights when the Gemini analysis call is unavailable —
    computed directly from the data so the feature degrades gracefully."""
    insights: list[str] = []
    kpi = data.get("kpi") or {}
    if kpi.get("top_route"):
        insights.append(f"Most requested route: {kpi['top_route']}.")
    if kpi.get("top_vehicle"):
        insights.append(f"{kpi['top_vehicle']} generates the most revenue.")
    categories = data.get("revenue_by_category") or []
    if categories:
        top = categories[0]
        insights.append(
            f"{top['category']} accounts for {top['percentage']}% of revenue "
            f"(€{top['revenue']:,.0f}).")
    seasonal = data.get("seasonal") or {}
    if seasonal.get("peak_months"):
        insights.append(f"Peak demand months: {', '.join(seasonal['peak_months'])}.")
    revenue = data.get("revenue_by_month") or []
    if revenue:
        total = sum(r["revenue"] for r in revenue)
        insights.append(
            f"€{total:,.0f} completed-booking revenue across the analysed period "
            f"({sum(r['booking_count'] for r in revenue)} trips).")
    return insights[:5]


@tool
async def run_business_analysis(
    analysis_type: str = "full_review",
    months_back: int = 6,
) -> dict:
    """Run a comprehensive business intelligence analysis (admin only).
    analysis_type: 'full_review' | 'revenue' | 'seasonal' | 'pricing_impact' | 'vehicles'.
    months_back: analysis window in months (default 6).
    Returns metrics, trends, chart specifications the app renders as interactive
    charts, KPIs, and an analyst narrative. Use for business reviews, revenue
    analysis, seasonal patterns, pricing-change impact, and vehicle performance."""
    from app.services import analytics_service as svc

    if analysis_type not in ("full_review", "revenue", "seasonal",
                             "pricing_impact", "vehicles"):
        analysis_type = "full_review"
    months_back = max(1, min(int(months_back or 6), 24))

    # ── Gather real data (only what the analysis type needs) ─────────────────
    data: dict = {"kpi": await svc.get_kpi_summary()}
    if analysis_type in ("full_review", "revenue", "seasonal"):
        data["revenue_by_month"] = await svc.get_revenue_by_month(months_back)
    if analysis_type in ("full_review", "revenue", "vehicles"):
        data["revenue_by_category"] = await svc.get_revenue_by_vehicle_category(months_back)
    if analysis_type in ("full_review", "seasonal"):
        data["booking_volume"] = await svc.get_booking_volume_trend(months_back)
        data["seasonal"] = await svc.get_seasonal_analysis()
    if analysis_type in ("full_review", "pricing_impact"):
        data["pricing_impact"] = await svc.get_pricing_impact_analysis()

    charts = _build_charts(analysis_type, data)
    kpis = _build_kpis(data["kpi"])
    fallback_insights = _deterministic_insights(data)

    # ── Dedicated analyst call (separate from the conversation turn). On any
    #    failure (quota etc.) the feature degrades to deterministic insights. ──
    narrative = None
    try:
        from app.ai.model_router import invoke_with_fallback
        import json as _json
        response = await invoke_with_fallback([
            ("system", _ANALYST_PROMPT),
            ("human", f"Analysis type: {analysis_type}\n\nDATA:\n"
                      f"{_json.dumps(data, default=str, indent=1)[:6000]}"),
        ])
        from app.ai.agents.shared import extract_text
        narrative = extract_text(response).strip() or None
    except Exception as exc:  # noqa: BLE001 — analytics must never crash the turn
        print(f"[analytics] analyst call unavailable ({exc!r}); using deterministic summary")

    if not narrative:
        narrative = (
            "Automated summary (analyst model unavailable): "
            + " ".join(fallback_insights)
        )

    return {
        "analysis_type": analysis_type,
        "months_back": months_back,
        "narrative": narrative,
        "charts": charts,
        "kpis": kpis,
        "insights": fallback_insights,
        "raw": {k: v for k, v in data.items() if k != "kpi"},
        "kpi_raw": data["kpi"],
    }


# ── Exported list ──────────────────────────────────────────────────────────────

ADMIN_TOOLS = [
    manage_fleet,
    manage_pricing_rules,
    manage_suppliers,
    manage_promotions,
    get_dashboard_analytics,
    get_admin_overview,
    list_all_bookings,
    list_users,
    update_booking_status,
    run_business_analysis,
]
