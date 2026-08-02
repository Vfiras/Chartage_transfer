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

_COMPANY = ("Carthage Transfer, a Tunisian private-transport company. "
            "All money figures are in EUR (€).")

# One focused system prompt per mode. The explicit "do NOT discuss X" clauses
# are what stop every analysis from collapsing into the same generic summary.
_MODE_PROMPTS: dict[str, str] = {
    "full_review": (
        f"You are the head business analyst for {_COMPANY} Assess overall "
        "business health across revenue, booking volume, fleet mix and "
        "seasonality together, and state a health rating (strong / stable / "
        "needs attention) in the summary line."
    ),
    "revenue": (
        f"You are analysing REVENUE data for {_COMPANY} Focus exclusively on "
        "income trends, revenue sources, average transaction value and "
        "financial health. Do NOT discuss booking volumes, cancellation "
        "rates, seasonal patterns or pricing changes."
    ),
    "bookings": (
        f"You are analysing BOOKING VOLUME data for {_COMPANY} Focus "
        "exclusively on volume trends, completion rate, cancellation "
        "patterns and conversion from booking to completed trip. Do NOT "
        "discuss revenue figures or euro amounts."
    ),
    "pricing": (
        f"You are analysing the IMPACT OF PRICE CHANGES for {_COMPANY} Focus "
        "exclusively on how each recorded price change moved booking volume "
        "in the seven days after it, versus the seven days before. Do NOT "
        "discuss seasonality, fleet mix or overall revenue."
    ),
    "seasonal": (
        f"You are analysing SEASONAL AND TIME-BASED PATTERNS for {_COMPANY} "
        "Focus exclusively on when demand rises and falls: peak and quiet "
        "months, week-over-week volume, and month-of-year distribution. Do "
        "NOT discuss revenue totals, pricing changes or vehicle categories."
    ),
    "vehicles": (
        f"You are analysing FLEET PERFORMANCE for {_COMPANY} Focus "
        "exclusively on comparing vehicle categories against each other: "
        "which earn the most, which are booked most often, and which "
        "under-perform. Do NOT discuss seasonality or pricing changes."
    ),
}

_NARRATIVE_FORMAT = (
    "Reply in EXACTLY this structure and nothing else:\n\n"
    "Summary: <one sentence headline>\n\n"
    "Key findings:\n"
    "• <finding>\n"
    "• <finding>\n"
    "• <finding>\n\n"
    "Recommendation: <one or two sentences of actionable advice>\n\n"
    "Rules: quote the exact figures from DATA (write money as €34, not "
    "'minimal'). Three findings maximum. No markdown headers, no bold, no "
    "preamble, no closing remark. Under 130 words in total."
)

_MODE_TITLES = {
    "full_review": "Business Review",
    "revenue": "Revenue Analysis",
    "bookings": "Booking Trends",
    "pricing": "Pricing Impact",
    "seasonal": "Seasonal Patterns",
    "vehicles": "Fleet Performance",
}


def _fmt_month(ym: str) -> str:
    """'2026-07' → 'Jul 2026' for chart labels."""
    try:
        return datetime.strptime(ym, "%Y-%m").strftime("%b %Y")
    except ValueError:
        return ym


def _eur(v) -> str:
    try:
        return f"€{float(v):,.0f}"
    except (TypeError, ValueError):
        return "€0"


# ── Chart builders ─────────────────────────────────────────────────────────────
#
# Each mode returns ONLY its own charts. The app renders whatever arrives, so a
# two-chart revenue answer and a five-chart full review both lay out correctly.

def _chart_monthly_revenue(rows: list[dict], as_bar: bool) -> dict | None:
    if not rows:
        return None
    peak = max(rows, key=lambda r: r["revenue"])
    return {
        "type": "bar" if as_bar else "line",
        "title": "Monthly Revenue" if len(rows) < 2
                 else f"Monthly Revenue (Last {len(rows)} Months)",
        "data": [{"label": _fmt_month(r["month"]), "value": r["revenue"]} for r in rows],
        "color_scheme": "gold",
        "unit": "eur",
        "highlight": _fmt_month(peak["month"]),
    }


def _chart_category_pie(rows: list[dict]) -> dict | None:
    if not rows:
        return None
    return {
        "type": "pie",
        "title": "Revenue by Vehicle Category",
        "data": [{"label": c["category"], "value": c["percentage"]} for c in rows],
        "color_scheme": "mixed",
        "unit": "percent",
    }


def _chart_weekly_volume(rows: list[dict]) -> dict | None:
    if not rows:
        return None
    return {
        "type": "area",
        "title": "Weekly Booking Volume",
        "data": [{"label": v["period"], "value": v["bookings"]} for v in rows],
        "color_scheme": "gold",
    }


def _chart_pricing_impact(rows: list[dict]) -> dict | None:
    if not rows:
        return None
    points: list[dict] = []
    for change in rows[:4]:
        # Short labels only — the chart axis truncates, and the vehicle name is
        # already in the narrative. MM-DD keeps the pairs distinguishable.
        when = change["change_date"][5:]
        points.append({"label": f"Pre {when}", "value": change["bookings_before_7d"]})
        points.append({"label": f"Post {when}", "value": change["bookings_after_7d"]})
    return {
        "type": "bar",
        "title": "Bookings 7 Days Before vs After Price Changes",
        "data": points,
        "color_scheme": "paired",
    }


def _build_charts(mode: str, data: dict) -> list[dict]:
    """Deterministic chart specs for one mode.
    Format consumed by the Flutter AnalyticsCard (type/title/data/color_scheme)."""
    revenue_months = data.get("revenue_by_month") or []
    categories = data.get("revenue_by_category") or []
    volume = data.get("booking_volume") or []
    impact = data.get("pricing_impact") or []
    stats = data.get("booking_stats") or {}
    seasonal = data.get("seasonal") or {}

    specs: list[dict | None] = []

    if mode == "full_review":
        specs += [
            _chart_monthly_revenue(revenue_months, as_bar=False),
            _chart_category_pie(categories),
            {"type": "bar",
             "title": "Completed Bookings per Month",
             "data": [{"label": _fmt_month(r["month"]), "value": r["booking_count"]}
                      for r in revenue_months],
             "color_scheme": "gold"} if revenue_months else None,
            _chart_weekly_volume(volume),
            _chart_pricing_impact(impact),
        ]

    elif mode == "revenue":
        specs += [
            _chart_monthly_revenue(revenue_months, as_bar=True),
            _chart_category_pie(categories),
        ]

    elif mode == "bookings":
        months = data.get("bookings_per_month") or []
        if months:
            specs.append({
                "type": "bar",
                "title": "Completed Bookings per Month",
                "data": [{"label": _fmt_month(m["month"]), "value": m["bookings"]}
                         for m in months],
                "color_scheme": "gold",
            })
        by_status = stats.get("by_status") or {}
        if by_status:
            specs.append({
                "type": "pie",
                "title": "Bookings by Status",
                "data": [{"label": k.replace("_", " ").title(), "value": v}
                         for k, v in sorted(by_status.items(),
                                            key=lambda kv: kv[1], reverse=True)],
                "color_scheme": "mixed",
            })

    elif mode == "pricing":
        specs.append(_chart_pricing_impact(impact))

    elif mode == "seasonal":
        specs.append(_chart_weekly_volume(volume))
        distribution = seasonal.get("monthly_booking_distribution") or {}
        if distribution:
            specs.append({
                "type": "line",
                "title": "Bookings by Month of Year",
                "data": [{"label": m[:3], "value": n} for m, n in distribution.items()],
                "color_scheme": "gold",
            })

    elif mode == "vehicles":
        specs.append(_chart_category_pie(categories))
        by_vehicle = stats.get("by_vehicle") or []
        if by_vehicle:
            specs.append({
                "type": "bar",
                "title": "Bookings by Vehicle Category",
                "data": [{"label": v["vehicle"], "value": v["bookings"]}
                         for v in by_vehicle[:6]],
                "color_scheme": "gold",
            })

    return [s for s in specs if s]


# ── KPI builders ───────────────────────────────────────────────────────────────

def _tile(label: str, value, trend: str | None = None, positive: bool = True) -> dict:
    return {"label": label, "value": str(value), "trend": trend, "positive": positive}


def _build_kpis(mode: str, data: dict) -> list[dict]:
    """Only the metrics that belong to this mode — a booking-trend answer must
    not lead with revenue tiles."""
    kpi = data.get("kpi") or {}
    stats = data.get("booking_stats") or {}
    categories = data.get("revenue_by_category") or []
    impact = data.get("pricing_impact") or []
    seasonal = data.get("seasonal") or {}

    def pct(v) -> str | None:
        return f"{v * 100:+.0f}%" if isinstance(v, (int, float)) else None

    mom, yoy = kpi.get("revenue_growth_mom"), kpi.get("revenue_growth_yoy")

    if mode in ("full_review", "revenue"):
        out = [
            _tile("Revenue MTD", _eur(kpi.get("total_revenue_mtd")),
                  pct(mom), (mom or 0) >= 0),
            _tile("Revenue YTD", _eur(kpi.get("total_revenue_ytd")),
                  pct(yoy), (yoy or 0) >= 0),
            _tile("Avg Booking", _eur(kpi.get("avg_booking_value"))),
            _tile("Completed Trips", kpi.get("completed_bookings", 0)),
        ]
        if mode == "full_review":
            out.insert(2, _tile("Bookings MTD", kpi.get("bookings_mtd", 0)))
            if kpi.get("top_vehicle"):
                out.append(_tile("Top Vehicle", kpi["top_vehicle"]))
        return out

    if mode == "bookings":
        cancel_rate = stats.get("cancellation_rate", 0)
        return [
            _tile("Total Bookings", stats.get("total", 0)),
            _tile("Completed", stats.get("completed", 0),
                  f"{stats.get('completion_rate', 0)}%", True),
            _tile("Cancelled", stats.get("cancelled", 0),
                  f"{cancel_rate}%", cancel_rate <= 10),
            _tile("Pending", stats.get("pending", 0)),
            _tile("Confirmed", stats.get("confirmed", 0)),
        ]

    if mode == "pricing":
        deltas = [c["bookings_after_7d"] - c["bookings_before_7d"] for c in impact]
        net = sum(deltas)
        improved = sum(1 for d in deltas if d > 0)
        return [
            _tile("Price Changes", len(impact)),
            _tile("Vehicles Affected", len({c["vehicle"] for c in impact})),
            _tile("Net Booking Delta", f"{net:+d}", None, net >= 0),
            _tile("Changes That Lifted", f"{improved}/{len(impact)}" if impact else "0/0"),
        ]

    if mode == "seasonal":
        volume = data.get("booking_volume") or []
        busiest = max(volume, key=lambda v: v["bookings"], default=None)
        peaks = seasonal.get("peak_months") or []
        slows = seasonal.get("slow_months") or []
        return [
            _tile("Peak Month", peaks[0] if peaks else "—"),
            _tile("Quiet Month", slows[-1] if slows else "—"),
            _tile("Busiest Week", busiest["period"].split("-")[-1] if busiest else "—",
                  f"{busiest['bookings']} trips" if busiest else None),
            _tile("Weeks Tracked", len(volume)),
        ]

    if mode == "vehicles":
        by_vehicle = stats.get("by_vehicle") or []
        top = categories[0] if categories else None
        return [
            _tile("Top Earner", top["category"] if top else "—",
                  f"{top['percentage']}%" if top else None),
            _tile("Top Revenue", _eur(top["revenue"]) if top else "€0"),
            _tile("Most Booked", by_vehicle[0]["vehicle"] if by_vehicle else "—",
                  f"{by_vehicle[0]['bookings']} trips" if by_vehicle else None),
            _tile("Categories Active", len(categories)),
        ]

    return []


# ── Deterministic insights + fallback narrative ────────────────────────────────

def _deterministic_insights(mode: str, data: dict) -> list[str]:
    """Insights computed straight from the data — always shown, and the source
    of the fallback narrative when the analyst model is unavailable."""
    kpi = data.get("kpi") or {}
    stats = data.get("booking_stats") or {}
    categories = data.get("revenue_by_category") or []
    seasonal = data.get("seasonal") or {}
    impact = data.get("pricing_impact") or []
    revenue_months = data.get("revenue_by_month") or []
    volume = data.get("booking_volume") or []
    out: list[str] = []

    if mode in ("full_review", "revenue"):
        out.append(f"Revenue YTD is {_eur(kpi.get('total_revenue_ytd'))} across "
                   f"{kpi.get('completed_bookings', 0)} completed trips.")
        out.append(f"Average booking value is {_eur(kpi.get('avg_booking_value'))}.")
        if revenue_months:
            best = max(revenue_months, key=lambda r: r["revenue"])
            out.append(f"Best month so far: {_fmt_month(best['month'])} at "
                       f"{_eur(best['revenue'])}.")
        if categories:
            top = categories[0]
            out.append(f"{top['category']} accounts for {top['percentage']}% of "
                       f"revenue ({_eur(top['revenue'])}).")

    if mode in ("full_review", "bookings"):
        if stats:
            out.append(f"{stats.get('total', 0)} bookings recorded, "
                       f"{stats.get('completion_rate', 0)}% completed and "
                       f"{stats.get('cancellation_rate', 0)}% cancelled.")
            if stats.get("pending"):
                out.append(f"{stats['pending']} bookings are still awaiting action.")

    if mode in ("full_review", "seasonal"):
        if seasonal.get("peak_months"):
            out.append(f"Peak demand months: {', '.join(seasonal['peak_months'])}.")
        if seasonal.get("slow_months"):
            out.append(f"Quietest months: {', '.join(seasonal['slow_months'])}.")
        if volume:
            busiest = max(volume, key=lambda v: v["bookings"])
            out.append(f"Busiest week was {busiest['period']} with "
                       f"{busiest['bookings']} bookings.")

    if mode in ("full_review", "pricing"):
        if impact:
            lifted = sum(1 for c in impact
                         if c["bookings_after_7d"] > c["bookings_before_7d"])
            out.append(f"{len(impact)} price changes recorded; {lifted} were "
                       f"followed by higher booking volume.")
            first = impact[0]
            out.append(f"{first['vehicle']}: {first['bookings_before_7d']} bookings "
                       f"before vs {first['bookings_after_7d']} after "
                       f"({first['impact']}).")
        elif mode == "pricing":
            out.append("No pricing changes have been recorded yet, so there is "
                       "nothing to correlate against booking volume.")

    if mode == "vehicles":
        if categories:
            top = categories[0]
            out.append(f"{top['category']} leads on revenue with "
                       f"{_eur(top['revenue'])} ({top['percentage']}% of the total).")
            if len(categories) > 1:
                last = categories[-1]
                out.append(f"{last['category']} trails at {_eur(last['revenue'])} "
                           f"({last['percentage']}%).")
        for v in (stats.get("by_vehicle") or [])[:1]:
            out.append(f"{v['vehicle']} is booked most often ({v['bookings']} trips).")
        if kpi.get("top_route"):
            out.append(f"Most requested route: {kpi['top_route']}.")

    if mode == "full_review" and kpi.get("top_route"):
        out.append(f"Most requested route: {kpi['top_route']}.")

    return out[:5]


def _fallback_narrative(mode: str, insights: list[str]) -> str:
    """Same Summary / findings / Recommendation shape as the model output, so
    the card layout is identical when the analyst call is unavailable."""
    title = _MODE_TITLES.get(mode, "Business Review")
    if not insights:
        return (f"Summary: Not enough data yet for a {title.lower()}.\n\n"
                "Key findings:\n• No completed bookings in the selected window.\n\n"
                "Recommendation: Revisit this once trips have been completed.")
    findings = "\n".join(f"• {i}" for i in insights[:3])
    return (f"Summary: {title} based on live figures ({insights[0]})\n\n"
            f"Key findings:\n{findings}\n\n"
            "Recommendation: Review these figures against the dashboard before "
            "acting — this summary was generated without the analyst model.")


@tool
async def run_business_analysis(
    analysis_type: str = "full_review",
    months_back: int = 6,
) -> dict:
    """Run a focused business-intelligence analysis (admin only).

    Pick the analysis_type that matches what the admin actually asked for —
    each one returns a DIFFERENT set of metrics and charts:
      • 'full_review' — overall health: revenue + bookings + fleet + seasonality.
        Use for "full business review", "how is the business doing".
      • 'revenue' — income only: MTD/YTD revenue, revenue by vehicle, monthly
        revenue trend. Use for "revenue", "income", "earnings", "how much money".
      • 'bookings' — volume only: totals by status, completion and cancellation
        rates, bookings per month. Use for "booking trends", "how many trips".
      • 'pricing' — price changes vs booking volume 7 days before/after. Use for
        "pricing impact", "how did prices affect bookings".
      • 'seasonal' — time patterns only: peak/quiet months, weekly volume. Use
        for "seasonal patterns", "peak periods", "when are we busiest".
      • 'vehicles' — fleet comparison only: revenue and bookings per category,
        top and bottom performers. Use for "fleet performance", "which car".

    months_back: analysis window in months (default 6).
    Returns KPIs, chart specifications the app renders as interactive charts,
    deterministic insights, and a structured analyst narrative."""
    from app.services import analytics_service as svc

    mode = svc.normalise_mode(analysis_type)
    months_back = max(1, min(int(months_back or 6), 24))

    # Only the aggregations this mode needs — this is what makes each answer
    # different rather than six views of one blob.
    data = await svc.collect(mode, months_back)

    charts = _build_charts(mode, data)
    kpis = _build_kpis(mode, data)
    insights = _deterministic_insights(mode, data)

    # ── Dedicated analyst call (separate from the conversation turn). On any
    #    failure (quota etc.) the feature degrades to the deterministic
    #    narrative, which uses the same Summary/findings/Recommendation shape. ──
    narrative = None
    try:
        from app.ai.model_router import invoke_with_fallback
        import json as _json
        headline = ", ".join(f"{k['label']} {k['value']}" for k in kpis[:5])
        response = await invoke_with_fallback([
            ("system", f"{_MODE_PROMPTS.get(mode, _MODE_PROMPTS['full_review'])}\n\n"
                       f"{_NARRATIVE_FORMAT}"),
            ("human", f"Analysis: {_MODE_TITLES.get(mode, mode)} "
                      f"(last {months_back} months)\n"
                      f"HEADLINE METRICS: {headline}\n\n"
                      f"DATA:\n{_json.dumps(data, default=str, indent=1)[:6000]}"),
        ])
        from app.ai.agents.shared import extract_text
        narrative = extract_text(response).strip() or None
    except Exception as exc:  # noqa: BLE001 — analytics must never crash the turn
        print(f"[analytics] analyst call unavailable ({exc!r}); using deterministic summary")

    if not narrative:
        narrative = _fallback_narrative(mode, insights)

    return {
        # analysis_type is kept for older clients; mode is the canonical field.
        "analysis_type": mode,
        "mode": mode,
        "title": _MODE_TITLES.get(mode, "Business Review"),
        "months_back": months_back,
        "narrative": narrative,
        "charts": charts,
        "kpis": kpis,
        "insights": insights,
        "raw": {k: v for k, v in data.items() if k not in ("kpi", "mode")},
        "kpi_raw": data.get("kpi", {}),
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
