"""
Business-intelligence data layer for AVA's analytics feature.

Every method queries real MongoDB collections (bookings, cars, pricing_history)
and returns plain JSON-serialisable structures.  No LLM involvement here —
this module is deterministic; the narrative/reasoning layer sits on top of it
(ai/tools_admin.run_business_analysis).

Revenue convention: bookings with status "completed" count as realised
revenue; monthly grouping uses departure_date (falls back to created_at).
"""
from __future__ import annotations

import calendar
from collections import defaultdict
from datetime import datetime, timedelta, timezone

from app.core.database import get_database

_MONTH_NAMES = list(calendar.month_name)  # [""] + Jan..Dec


def _booking_month(booking: dict) -> str | None:
    """Return 'YYYY-MM' for a booking, preferring departure_date."""
    raw = booking.get("departure_date") or ""
    if isinstance(raw, str) and len(raw) >= 7 and raw[4] == "-":
        return raw[:7]
    created = booking.get("created_at")
    if isinstance(created, datetime):
        return created.strftime("%Y-%m")
    return None


def _booking_dt(booking: dict) -> datetime | None:
    """Best-effort datetime for a booking (departure date, else created_at)."""
    raw = booking.get("departure_date") or ""
    if isinstance(raw, str) and len(raw) >= 10:
        try:
            return datetime.fromisoformat(raw[:10]).replace(tzinfo=timezone.utc)
        except ValueError:
            pass
    created = booking.get("created_at")
    if isinstance(created, datetime):
        return created if created.tzinfo else created.replace(tzinfo=timezone.utc)
    return None


async def _completed_bookings() -> list[dict]:
    db = get_database()
    out: list[dict] = []
    async for b in db.bookings.find({"status": "completed"}):
        out.append(b)
    return out


async def _all_bookings() -> list[dict]:
    db = get_database()
    out: list[dict] = []
    async for b in db.bookings.find({}):
        out.append(b)
    return out


# ── Revenue by month ───────────────────────────────────────────────────────────

async def get_revenue_by_month(months_back: int = 12) -> list[dict]:
    """Completed bookings grouped by month: revenue + booking count."""
    cutoff = datetime.now(timezone.utc) - timedelta(days=31 * months_back)
    buckets: dict[str, dict] = defaultdict(lambda: {"revenue": 0.0, "booking_count": 0})
    for b in await _completed_bookings():
        month = _booking_month(b)
        dt = _booking_dt(b)
        if not month or (dt and dt < cutoff):
            continue
        buckets[month]["revenue"] += float(b.get("total_price", 0) or 0)
        buckets[month]["booking_count"] += 1
    return [
        {"month": m, "revenue": round(v["revenue"], 2), "booking_count": v["booking_count"]}
        for m, v in sorted(buckets.items())
    ]


# ── Revenue by vehicle category ────────────────────────────────────────────────

async def get_revenue_by_vehicle_category(months_back: int = 3) -> list[dict]:
    """Revenue share per vehicle class over the window."""
    cutoff = datetime.now(timezone.utc) - timedelta(days=31 * months_back)
    revenue: dict[str, float] = defaultdict(float)
    for b in await _completed_bookings():
        dt = _booking_dt(b)
        if dt and dt < cutoff:
            continue
        label = b.get("vehicle_class") or b.get("vehicle_type") or "Unknown"
        revenue[label] += float(b.get("total_price", 0) or 0)
    total = sum(revenue.values()) or 1.0
    ranked = sorted(revenue.items(), key=lambda kv: kv[1], reverse=True)
    return [
        {
            "category": cat,
            "revenue": round(val, 2),
            "percentage": round(val / total * 100, 1),
        }
        for cat, val in ranked
    ]


# ── Booking volume trend ───────────────────────────────────────────────────────

async def get_booking_volume_trend(months_back: int = 12) -> list[dict]:
    """Weekly booking counts (ISO week) across all bookings, any status —
    volume measures demand, not just completion."""
    cutoff = datetime.now(timezone.utc) - timedelta(days=31 * months_back)
    buckets: dict[str, int] = defaultdict(int)
    for b in await _all_bookings():
        dt = _booking_dt(b)
        if not dt or dt < cutoff:
            continue
        iso = dt.isocalendar()
        buckets[f"{iso[0]}-W{iso[1]:02d}"] += 1
    return [{"period": p, "bookings": n} for p, n in sorted(buckets.items())]


# ── Seasonal analysis ──────────────────────────────────────────────────────────

async def get_seasonal_analysis() -> dict:
    """Peak/slow months from booking volume; YoY growth when 2+ years exist."""
    by_month_name: dict[int, int] = defaultdict(int)       # 1..12 -> bookings
    by_year_month: dict[str, float] = defaultdict(float)   # YYYY-MM -> revenue
    for b in await _all_bookings():
        dt = _booking_dt(b)
        if not dt:
            continue
        by_month_name[dt.month] += 1
        if b.get("status") == "completed":
            by_year_month[dt.strftime("%Y-%m")] += float(b.get("total_price", 0) or 0)

    if not by_month_name:
        return {"peak_months": [], "slow_months": [], "yoy_growth": None,
                "note": "No dated bookings available yet."}

    ranked = sorted(by_month_name.items(), key=lambda kv: kv[1], reverse=True)
    peak = [_MONTH_NAMES[m] for m, _ in ranked[:2]]
    slow = [_MONTH_NAMES[m] for m, _ in ranked[-2:]] if len(ranked) > 2 else []

    # YoY: compare same months across consecutive years where both exist
    yoy = None
    years = sorted({ym[:4] for ym in by_year_month})
    if len(years) >= 2:
        prev_year, last_year = years[-2], years[-1]
        prev_total = sum(v for ym, v in by_year_month.items() if ym.startswith(prev_year))
        last_total = sum(v for ym, v in by_year_month.items() if ym.startswith(last_year))
        if prev_total > 0:
            yoy = round((last_total - prev_total) / prev_total, 3)

    return {
        "peak_months": peak,
        "slow_months": slow,
        "yoy_growth": yoy,
        "monthly_booking_distribution": {
            _MONTH_NAMES[m]: n for m, n in sorted(by_month_name.items())
        },
    }


# ── Pricing impact analysis ────────────────────────────────────────────────────

async def get_pricing_impact_analysis() -> list[dict]:
    """Correlate pricing changes with booking volume 7 days before/after.

    Sources, in order: the pricing_history collection (written on every admin
    pricing edit), else inferred from car documents whose updated_at differs
    from created_at."""
    db = get_database()
    changes: list[dict] = []

    async for h in db.pricing_history.find({}).sort([("changed_at", 1)]):
        changes.append({
            "change_date": h.get("changed_at"),
            "vehicle": h.get("vehicle_name", h.get("car_id", "unknown")),
            "old_price": h.get("old_initial_fee"),
            "new_price": h.get("new_initial_fee"),
        })

    if not changes:
        # Inference fallback: a car edited after creation implies a change
        async for car in db.cars.find({}):
            created, updated = car.get("created_at"), car.get("updated_at")
            if (isinstance(created, datetime) and isinstance(updated, datetime)
                    and (updated - created) > timedelta(minutes=5)):
                changes.append({
                    "change_date": updated,
                    "vehicle": car.get("name", car.get("_id")),
                    "old_price": None,  # unknown — inferred change
                    "new_price": (car.get("pricing") or {}).get(
                        "initial_fee", car.get("base_price")),
                })

    bookings = await _all_bookings()
    results: list[dict] = []
    for change in changes:
        when = change["change_date"]
        if not isinstance(when, datetime):
            continue
        when = when if when.tzinfo else when.replace(tzinfo=timezone.utc)
        before = sum(
            1 for b in bookings
            if (dt := _booking_dt(b)) and when - timedelta(days=7) <= dt < when
        )
        after = sum(
            1 for b in bookings
            if (dt := _booking_dt(b)) and when <= dt < when + timedelta(days=7)
        )
        if before > 0:
            impact = f"{(after - before) / before * 100:+.0f}%"
        else:
            impact = "n/a (no bookings in prior week)" if after == 0 else f"+{after} new"
        results.append({
            "change_date": when.strftime("%Y-%m-%d"),
            "vehicle": change["vehicle"],
            "old_price": change["old_price"],
            "new_price": change["new_price"],
            "bookings_before_7d": before,
            "bookings_after_7d": after,
            "impact": impact,
        })
    return results


# ── KPI summary ────────────────────────────────────────────────────────────────

async def get_kpi_summary() -> dict:
    """Single-call full picture: MTD/YTD revenue, growth, top route/vehicle."""
    now = datetime.now(timezone.utc)
    this_month = now.strftime("%Y-%m")
    last_month = (now.replace(day=1) - timedelta(days=1)).strftime("%Y-%m")
    this_year = now.strftime("%Y")
    last_year = str(int(this_year) - 1)

    completed = await _completed_bookings()
    all_bookings = await _all_bookings()

    def rev(pred) -> float:
        return sum(float(b.get("total_price", 0) or 0)
                   for b in completed if pred(_booking_month(b) or ""))

    revenue_mtd = rev(lambda m: m == this_month)
    revenue_last_month = rev(lambda m: m == last_month)
    revenue_ytd = rev(lambda m: m.startswith(this_year))
    revenue_last_year = rev(lambda m: m.startswith(last_year))

    bookings_mtd = sum(1 for b in all_bookings if (_booking_month(b) or "") == this_month)
    total_completed_value = sum(float(b.get("total_price", 0) or 0) for b in completed)
    avg_value = round(total_completed_value / len(completed), 2) if completed else 0.0

    routes: dict[str, int] = defaultdict(int)
    vehicles: dict[str, float] = defaultdict(float)
    for b in completed:
        routes[f"{b.get('pickup_location', '?')} → {b.get('destination_name', '?')}"] += 1
        vehicles[b.get("vehicle_class") or b.get("vehicle_type") or "Unknown"] += \
            float(b.get("total_price", 0) or 0)

    top_route = max(routes.items(), key=lambda kv: kv[1])[0] if routes else None
    top_vehicle = max(vehicles.items(), key=lambda kv: kv[1])[0] if vehicles else None

    mom = round((revenue_mtd - revenue_last_month) / revenue_last_month, 3) \
        if revenue_last_month > 0 else None
    yoy = round((revenue_ytd - revenue_last_year) / revenue_last_year, 3) \
        if revenue_last_year > 0 else None

    return {
        "total_revenue_mtd": round(revenue_mtd, 2),
        "total_revenue_ytd": round(revenue_ytd, 2),
        "bookings_mtd": bookings_mtd,
        "total_bookings": len(all_bookings),
        "completed_bookings": len(completed),
        "avg_booking_value": avg_value,
        "top_route": top_route,
        "top_vehicle": top_vehicle,
        "revenue_growth_mom": mom,
        "revenue_growth_yoy": yoy,
        "currency": "EUR",
    }
