"""
Client-facing LangChain tools for the AVA agent.

Each tool is an async @tool-decorated function that calls the same DB/service
logic as the existing API routes — no HTTP round-trips.

Identity (user_id) is an explicit parameter here.  The tool_registry in
Checkpoint 4 will bind it in via functools.partial before handing the tool
list to the LLM, so the LLM never sees user_id in the schema.
"""
from __future__ import annotations

import sys, os
_backend_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
if _backend_dir not in sys.path:
    sys.path.insert(0, _backend_dir)

from collections import Counter
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

from langchain_core.tools import tool

from app.core.database import get_database
from app.services.booking_service import (
    create_trip,
    get_pricing_rules,
    get_trip_history as _get_trip_history,
    update_trip,
    update_trip_status,
)
from app.services.utils import serialize_document
from app.api.v1.endpoints.complaints import create_complaint_record


# ── Duration formatting ───────────────────────────────────────────────────────

def format_duration(hours: float) -> str:
    """Human-friendly duration for error messages.

    Examples:
      1.0  -> "1 hour"          (whole numbers drop the ".0" and pluralize)
      2.0  -> "2 hours"
      1.5  -> "1.5 hours"       (genuinely fractional values keep one decimal)
      0.5  -> "30 minutes"      (sub-hour values render as whole minutes)
      24   -> "24 hours"
    """
    if hours < 1:
        minutes = max(1, round(hours * 60))
        return f"{minutes} minute{'s' if minutes != 1 else ''}"
    rounded = round(hours, 1)
    if rounded == int(rounded):
        n = int(rounded)
        return f"{n} hour{'s' if n != 1 else ''}"
    return f"{rounded} hours"


# ── Lazy RAG store initialisation ─────────────────────────────────────────────
_rag_store = None

def _get_rag_store():
    global _rag_store
    if _rag_store is None:
        from langchain_huggingface import HuggingFaceEmbeddings
        from langchain_chroma import Chroma
        from app.ai.build_vectorstore import VECTORSTORE_DIR, EMBED_MODEL, COLLECTION_NAME
        embeddings = HuggingFaceEmbeddings(model_name=EMBED_MODEL)
        _rag_store = Chroma(
            collection_name=COLLECTION_NAME,
            embedding_function=embeddings,
            persist_directory=str(VECTORSTORE_DIR),
        )
    return _rag_store


# ── Internal price computation ────────────────────────────────────────────────

async def _compute_price(
    vehicle_type: str,
    date: str,
    time: str,
    promo_code: Optional[str] = None,
    user_id: Optional[str] = None,
) -> tuple[float, float, float]:
    """Return (base_price, dynamic_surcharge, discount_amount).
    Mirrors the same rules that pricing.py applies so the LLM never supplies a price.
    """
    db = get_database()

    car = await db.cars.find_one({"category": vehicle_type, "availability": True})
    base = float(car["base_price"]) if car and "base_price" in car else 0.0

    rules = await get_pricing_rules()

    try:
        dep_dt = datetime.strptime(f"{date} {time}", "%Y-%m-%d %H:%M").replace(
            tzinfo=timezone.utc
        )
    except ValueError:
        return base, 0.0, 0.0

    surcharge_pct = 0.0

    # Night surcharge (window may cross midnight, e.g. 22:00–06:00)
    night = rules.get("night_pricing") or {}
    if night.get("enabled"):
        try:
            sh, sm = (int(x) for x in str(night.get("start_time", "22:00")).split(":"))
            eh, em = (int(x) for x in str(night.get("end_time", "06:00")).split(":"))
            dep_mins   = dep_dt.hour * 60 + dep_dt.minute
            start_mins = sh * 60 + sm
            end_mins   = eh * 60 + em
            if start_mins > end_mins:  # crosses midnight
                is_night = dep_mins >= start_mins or dep_mins < end_mins
            else:
                is_night = start_mins <= dep_mins < end_mins
            if is_night:
                surcharge_pct += float(night.get("percentage", 30))
        except (ValueError, TypeError, AttributeError):
            pass

    # Last-minute surcharge
    lm = rules.get("last_minute_pricing") or {}
    if lm.get("enabled"):
        hours_until = (dep_dt - datetime.now(timezone.utc)).total_seconds() / 3600
        if hours_until < float(lm.get("within_hours", 24)):
            surcharge_pct += float(lm.get("percentage", 20))

    # Weekend surcharge (Saturday=5, Sunday=6)
    wk = rules.get("weekend_pricing") or {}
    if wk.get("enabled") and dep_dt.weekday() in (5, 6):
        surcharge_pct += float(wk.get("percentage", 10))

    # Seasonal surcharge
    se = rules.get("seasonal_pricing") or {}
    if se.get("enabled"):
        surcharge_pct += float(se.get("percentage", 0))

    dynamic_surcharge = round(base * surcharge_pct / 100, 2)
    subtotal = base + dynamic_surcharge

    # Promo discount — reuse the same expiry/limit checks as pricing.py
    discount = 0.0
    if promo_code:
        code = promo_code.strip().upper()
        promo = await db.promotions.find_one({"code": code, "active": True})
        # Ownership: tier/welcome/referral codes are private to one member.
        # pricing.py enforces this on the HTTP path; without the same check
        # here, booking through AVA would honour someone else's code.
        if promo and promo.get("owner_user_id") not in (None, user_id):
            promo = None
        if promo:
            expiry_raw = promo.get("expiry_date")
            if expiry_raw:
                try:
                    if isinstance(expiry_raw, str):
                        exp_dt = datetime.fromisoformat(expiry_raw.replace("Z", "+00:00"))
                        if not exp_dt.tzinfo:
                            exp_dt = exp_dt.replace(tzinfo=timezone.utc)
                    else:
                        exp_dt = expiry_raw if expiry_raw.tzinfo else expiry_raw.replace(tzinfo=timezone.utc)
                    if exp_dt < datetime.now(timezone.utc):
                        promo = None
                except (ValueError, AttributeError):
                    promo = None
        if promo:
            limit = promo.get("usage_limit", 0)
            count = promo.get("usage_count", 0)
            if limit and count >= limit:
                promo = None
        if promo:
            val = float(promo.get("value", 0))
            if promo.get("discount_type") == "percentage":
                discount = round(subtotal * val / 100, 2)
            else:
                discount = round(min(float(val), subtotal), 2)

    return base, dynamic_surcharge, discount


# ── 1. RAG knowledge base ──────────────────────────────────────────────────────

# Minimum relevance a chunk must clear to be treated as grounding context.
# Derived from observed scores (June 2026 audit): genuinely on-topic, answerable
# queries score ~0.36–0.57, while queries whose answer is NOT in the KB score
# ~0.10–0.13 (and a past stale-index false-confidence case sat at 0.21).  A floor
# of 0.25 clears the absent-topic band with margin, sits above that 0.21 case, and
# stays below the closest legitimate query (0.36).  Below the floor a chunk is
# more likely an off-topic neighbour than a real answer; dropping it (and, if
# nothing survives, returning empty context) lets the persona's rule 5
# ("say you don't have it") fire cleanly instead of confidently paraphrasing a
# barely-relevant chunk.
_RELEVANCE_FLOOR = 0.25

# Below this best-score the first retrieval is "low-confidence" — likely a
# vocabulary mismatch between the user's phrasing and the KB text (e.g.
# "airport assistance" never appears verbatim in the FAQ, whose chunks talk
# about "driver holding a sign", "free waiting time", "flight delayed").
# For such queries we retry with an expanded phrasing and merge the results.
# 0.50: bare "airport assistance" scores 0.4954 against the (wrong) AIRPORTS
# SERVED chunk — it must fall under the bar so the expansion pulls in the
# actual meet-your-driver / waiting-time / flight-tracking chunks.
_CONFIDENT_SCORE = 0.50

# Query-expansion map: trigger word → KB-vocabulary expansion. Used only when
# the first pass is low-confidence, so well-matched queries are unaffected.
_QUERY_EXPANSIONS: list[tuple[str, str]] = [
    (
        "airport",
        "airport transfer meeting the driver name sign free waiting time "
        "flight delayed or arrives early",
    ),
]


@tool
async def search_knowledge_base(query: str) -> list[dict]:
    """Search the Carthage Transfer knowledge base (pricing policy, T&C, FAQ,
    vehicles, destinations).  Returns the most relevant text chunks (up to 3) with
    their relevance scores, dropping any below the relevance floor.  If nothing
    clears the floor, returns an empty list — meaning the knowledge base does not
    cover the question, so the answer should admit that rather than guess.  Use
    this to answer questions about company policy, surcharges, cancellation rules,
    vehicle types, or destination information."""
    store = _get_rag_store()
    results = store.similarity_search_with_relevance_scores(query, k=3)

    # Low-confidence first pass → retry with a KB-vocabulary expansion and
    # merge (dedupe by content, keep the best score per chunk, top 3 overall).
    best = max((score for _, score in results), default=0.0)
    if best < _CONFIDENT_SCORE:
        lowered = query.lower()
        for trigger, expansion in _QUERY_EXPANSIONS:
            if trigger in lowered:
                extra = store.similarity_search_with_relevance_scores(expansion, k=3)
                merged: dict[str, tuple] = {}
                for doc, score in [*results, *extra]:
                    key = doc.page_content
                    if key not in merged or score > merged[key][1]:
                        merged[key] = (doc, score)
                results = sorted(merged.values(), key=lambda p: p[1], reverse=True)[:3]
                break

    return [
        {
            "score": round(score, 4),
            "source": Path(doc.metadata.get("source", "unknown")).name,
            "content": doc.page_content,
        }
        for doc, score in results
        if score >= _RELEVANCE_FLOOR
    ]


# ── 2. Trip history ────────────────────────────────────────────────────────────

@tool
async def get_trip_history(user_id: str) -> dict:
    """Return the authenticated client's booking history grouped into
    'upcoming' (pending/confirmed/on_route) and 'past' (completed/cancelled)."""
    return await _get_trip_history(user_id=user_id)


# ── 3. Create booking ──────────────────────────────────────────────────────────

@tool
async def create_booking(
    user_id: str,
    departure: str,
    arrival: str,
    date: str,
    time: str,
    vehicle_type: str,
    passenger_count: int,
    trip_type: str = "one-way",
    passenger_name: str = "Guest",
    passenger_phone: str = "",
    promo_code: Optional[str] = None,
) -> dict:
    """Create a new transfer booking for the client.  Price is computed
    server-side from the fleet base rate plus active surcharges and any promo
    discount — the LLM must not supply a price.
    departure: pickup city or address.
    arrival: destination city or address.
    date: departure date in YYYY-MM-DD format.
    time: departure time in HH:MM format.
    vehicle_type: one of Standard, VIP, Luxury, Van.
    passenger_count: number of passengers (1–7).
    trip_type: 'one-way' or 'round-trip'.
    Returns the created booking (with computed total_price) or an error dict."""
    # Enforce minimum booking hours
    rules = await get_pricing_rules()
    min_hours = rules.get("minimum_booking_hours", 3)
    try:
        ride_dt = datetime.strptime(f"{date} {time}", "%Y-%m-%d %H:%M").replace(
            tzinfo=timezone.utc
        )
        hours_until = (ride_dt - datetime.now(timezone.utc)).total_seconds() / 3600
        if hours_until < min_hours:
            return {
                "error": f"Booking must be made at least {format_duration(min_hours)} in advance. "
                         f"Departure is in {format_duration(hours_until)}."
            }
    except ValueError:
        pass  # unparseable date/time — let service layer handle it

    # Compute price internally — LLM never supplies this
    base_price, dynamic_surcharge, discount_amount = await _compute_price(
        vehicle_type, date, time, promo_code, user_id
    )
    total_price = round(base_price + dynamic_surcharge - discount_amount, 2)

    data = {
        "user_id": user_id,
        "passenger_name": passenger_name,
        "passenger_phone": passenger_phone,
        "pickup_location": departure,
        "destination_name": arrival,
        "destination_city": arrival,
        "vehicle_class": vehicle_type,
        "vehicle_type": vehicle_type,
        "departure_date": date,
        "departure_time": time,
        "passenger_count": passenger_count,
        "trip_type": trip_type,
        "promo_code": promo_code,
        "dynamic_surcharge": dynamic_surcharge,
        "discount_amount": discount_amount,
        "total_price": total_price,
        "status": "pending",
        "is_guest": False,
    }

    # Increment promo usage count once at booking time (mirrors the HTTP route)
    if promo_code:
        db = get_database()
        await db.promotions.update_one(
            {"code": promo_code.upper()},
            {"$inc": {"usage_count": 1}, "$set": {"updated_at": datetime.now(timezone.utc)}},
        )

    return await create_trip(data)


# ── 4. Update booking ──────────────────────────────────────────────────────────

@tool
async def update_booking(
    user_id: str,
    booking_id: str,
    passenger_name: Optional[str] = None,
    passenger_phone: Optional[str] = None,
    pickup_location: Optional[str] = None,
    destination_name: Optional[str] = None,
    departure_date: Optional[str] = None,
    departure_time: Optional[str] = None,
    passenger_count: Optional[int] = None,
    luggage_count: Optional[int] = None,
) -> dict:
    """Modify an existing booking for the client.

    You MUST supply at least one field to change. If the client has only said
    they want to modify a booking without saying WHAT to change, do not call
    this tool — ask them what to change first (date, time, pickup address,
    destination, or passenger/luggage count).

    Only fields supplied are updated. Modification is blocked within 24 hours
    of departure. Returns the updated booking plus a `changes` list describing
    exactly what moved, or an error dict."""
    db = get_database()
    booking = await db.bookings.find_one({"_id": booking_id})
    if not booking:
        return {"error": "Booking not found"}
    booking = serialize_document(booking) or {}
    if booking.get("user_id") != user_id:
        return {"error": "Access denied — this booking does not belong to you"}

    rules = await get_pricing_rules()
    limit = rules.get("modification_limit_hours", 24)
    date_str = booking.get("departure_date", "")
    time_str = booking.get("departure_time", "")
    if date_str and time_str:
        try:
            ride_dt = datetime.strptime(f"{date_str} {time_str}", "%Y-%m-%d %H:%M").replace(
                tzinfo=timezone.utc
            )
            hours_until = (ride_dt - datetime.now(timezone.utc)).total_seconds() / 3600
            if hours_until < limit:
                return {
                    "error": f"Modification is only allowed up to {format_duration(limit)} before departure. "
                             f"Departure is in {format_duration(hours_until)}."
                }
        except ValueError:
            pass

    fields = {
        "passenger_name": passenger_name,
        "passenger_phone": passenger_phone,
        "pickup_location": pickup_location,
        "destination_name": destination_name,
        "departure_date": departure_date,
        "departure_time": departure_time,
        "passenger_count": passenger_count,
        "luggage_count": luggage_count,
    }

    # Only values that differ from what is stored count as a change. Without
    # this, calling the tool with nothing to change wrote nothing yet returned
    # the booking — which reads as success, so AVA confirmed a modification
    # that never happened.
    supplied = {k: v for k, v in fields.items() if v is not None}
    changes = [
        {
            "field": k,
            "from": booking.get(k),
            "to": v,
        }
        for k, v in supplied.items()
        if str(booking.get(k) or "") != str(v)
    ]

    if not supplied:
        return {
            "error": "no_changes_specified",
            "message": "Ask the client what they would like to change before "
                       "calling this tool.",
            "changeable_fields": [
                "departure_date", "departure_time", "pickup_location",
                "destination_name", "passenger_count", "luggage_count",
                "passenger_name", "passenger_phone",
            ],
            "current_values": {k: booking.get(k) for k in fields},
        }

    if not changes:
        return {
            "error": "values_unchanged",
            "message": "Every supplied value already matches the booking. "
                       "Confirm with the client what should be different.",
            "current_values": {k: booking.get(k) for k in supplied},
        }

    updated = await update_trip(booking_id, supplied)
    if not updated:
        return {"error": "Update failed"}
    return {"booking": updated, "changes": changes, "updated": True}


# ── 5. Cancel booking ──────────────────────────────────────────────────────────

@tool
async def cancel_booking(user_id: str, booking_id: str) -> dict:
    """Cancel a client's booking.  Cancellation is blocked within 24 hours of
    departure.  Returns the updated booking or an error dict."""
    db = get_database()
    booking = await db.bookings.find_one({"_id": booking_id})
    if not booking:
        return {"error": "Booking not found"}
    booking = serialize_document(booking) or {}

    if booking.get("user_id") != user_id:
        return {"error": "Access denied — this booking does not belong to you"}

    if booking.get("status") in ("completed", "cancelled"):
        return {"error": f"Cannot cancel — booking is already {booking['status']}"}

    rules = await get_pricing_rules()
    limit = rules.get("cancellation_limit_hours", 24)
    date_str = booking.get("departure_date", "")
    time_str = booking.get("departure_time", "")
    if date_str and time_str:
        try:
            ride_dt = datetime.strptime(f"{date_str} {time_str}", "%Y-%m-%d %H:%M").replace(
                tzinfo=timezone.utc
            )
            hours_until = (ride_dt - datetime.now(timezone.utc)).total_seconds() / 3600
            if hours_until < limit:
                return {
                    "error": f"Cancellation is only allowed up to {format_duration(limit)} before departure. "
                             f"Departure is in {format_duration(hours_until)}."
                }
        except ValueError:
            pass

    updated = await update_trip_status(booking_id, "cancelled")
    return updated or {"error": "Cancellation failed"}


# ── 6. Vehicle recommendation ──────────────────────────────────────────────────

# Rough distance for the price estimate shown in recommendations — a typical
# airport transfer (e.g. Tunis-Carthage → Hammamet is ~73 km by road).
_TYPICAL_TRANSFER_KM = 60.0


def _vehicle_summary(car: dict, trip_type: str) -> dict:
    """Compact, LLM-safe view of a real vehicle document: exact name/model/
    capacity plus an estimated price from the REAL pricing parameters."""
    from app.services.pricing_calculator import calculate_price

    quote = calculate_price(car, _TYPICAL_TRANSFER_KM, trip_type=trip_type)
    return {
        "name": car.get("name"),
        "model": car.get("model"),
        "category": car.get("category"),
        "seats": car.get("seats"),
        "luggage": car.get("luggage"),
        "estimated_price_eur": quote["total_eur"],
        "estimate_basis_km": _TYPICAL_TRANSFER_KM,
        # kept for the deterministic template fallback
        "base_price": car.get("base_price"),
    }


@tool
async def recommend_vehicle(
    passenger_count: int,
    trip_type: str,
    user_id: str,
) -> dict:
    """Recommend the best vehicle for the client based on passenger count,
    trip type, and their past booking preferences.
    passenger_count: total number of travellers including the client.
    trip_type: 'one-way' or 'round-trip'.
    Returns the recommended vehicle and the top matching options with real
    names, capacities, and estimated prices (EUR, ~60 km transfer basis)."""
    db = get_database()

    # Real fleet: available vehicles that fit the group, cheapest initial fee first
    cars: list[dict] = []
    async for car in db.cars.find({"availability": True}):
        cars.append(serialize_document(car) or {})

    eligible = [c for c in cars if c.get("seats", 0) >= passenger_count]
    if not eligible:
        return {"error": f"No available vehicle fits {passenger_count} passengers"}
    eligible.sort(
        key=lambda c: (c.get("pricing") or {}).get("initial_fee", c.get("base_price", 0.0))
    )

    # User's last 5 bookings to detect category/name preference
    history: list[dict] = []
    async for b in db.bookings.find({"user_id": user_id}).sort([("created_at", -1)]).limit(5):
        history.append(serialize_document(b) or {})

    preferred = Counter(
        b.get("vehicle_class") or b.get("vehicle_type")
        for b in history
        if b.get("vehicle_class") or b.get("vehicle_type")
    )

    # Preferred vehicle (matched by name OR category) if it fits, else cheapest
    recommended = None
    if preferred:
        top_pref = (preferred.most_common(1)[0][0] or "").lower()
        recommended = next(
            (c for c in eligible
             if (c.get("name", "").lower() == top_pref
                 or c.get("category", "").lower() == top_pref)),
            None,
        )
    if not recommended:
        recommended = eligible[0]  # cheapest that fits

    top_matches = [_vehicle_summary(c, trip_type) for c in eligible[:3]]
    return {
        "recommended": _vehicle_summary(recommended, trip_type),
        "eligible_vehicles": top_matches,
        "based_on_preference": bool(preferred),
        "preference_history": dict(preferred),
    }


# ── 7. User promos & rewards ───────────────────────────────────────────────────

@tool
async def get_user_promos(user_id: str) -> dict:
    """Return the client's loyalty programme status (points, tier, next tier)
    and the list of currently active promotional codes they can use.

    Thresholds are expressed in POINTS, and points accrue at points_per_trip per
    completed trip.  The gap to the next tier is PRE-COMPUTED here — in both
    points and trips — so the language model never has to infer the unit or do
    the division itself (it got that wrong: '50 points' read as '50 trips').
    The model only has to read the numbers back.  At the top tier (no next tier)
    both gaps are 0 — never negative, never a crash.
    """
    # Tiers, points and promo visibility all come from rewards_service — the
    # same code path behind GET /rewards/me and the admin loyalty view. This
    # tool used to keep its own copy of the tier table (0/50/150/300) which had
    # drifted from the real one (0/30/100/200), so AVA quoted thresholds that
    # contradicted the client's own Rewards screen.
    from app.services import rewards_service as rw

    db = get_database()

    points_per_trip = rw.POINTS_PER_TRIP
    completed_trips = await db.bookings.count_documents(
        {"user_id": user_id, "status": "completed"}
    )
    points = completed_trips * points_per_trip
    tier, next_tier, next_threshold = rw.resolve_tier(points)

    # Pre-compute the gap to the next tier in BOTH points and trips.
    # Top tier (next_threshold is None) → no next tier → both gaps are 0.
    if next_threshold is None:
        points_to_next_tier = 0
        trips_to_next_tier = 0
    else:
        points_to_next_tier = max(0, next_threshold - points)
        # Ceiling division: a partial trip still counts as one more trip.
        trips_to_next_tier = -(-points_to_next_tier // points_per_trip)

    # Only this client's own codes plus global ones. The unfiltered query used
    # here before advertised other members' private tier/welcome codes, which
    # the promo validator then correctly refused at checkout.
    promos = [serialize_document(p) or {} for p in await rw.visible_promos(user_id)]

    return {
        "points": points,
        "completed_trips": completed_trips,
        "points_per_trip": points_per_trip,
        "tier": tier,
        "next_tier": next_tier,
        "next_tier_threshold": next_threshold,
        "points_to_next_tier": points_to_next_tier,
        "trips_to_next_tier": trips_to_next_tier,
        "available_promos": promos,
    }


# ── 8. Submit complaint / claim ────────────────────────────────────────────────

@tool
async def submit_claim(user_id: str, booking_id: Optional[str], message: str) -> dict:
    """Submit a support complaint or feedback on behalf of the client.
    booking_id: optional — the booking this complaint relates to.
    message: the client's complaint or feedback text.
    Returns the created complaint record."""
    return await create_complaint_record(
        user_id=user_id,
        booking_id=booking_id,
        message=message,
    )


# ── Exported tool list ─────────────────────────────────────────────────────────

CLIENT_TOOLS = [
    search_knowledge_base,
    get_trip_history,
    create_booking,
    update_booking,
    cancel_booking,
    recommend_vehicle,
    get_user_promos,
    submit_claim,
]
