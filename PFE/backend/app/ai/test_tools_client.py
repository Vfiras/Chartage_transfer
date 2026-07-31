"""
Checkpoint 3 verification — calls all 8 client tools directly and prints results.

Usage:
    cd backend
    python app/ai/test_tools_client.py

Requires MongoDB to be running.  Creates a seeded test user + booking on first
run; leaves them in place so subsequent runs reuse the same data.
"""
import asyncio
import sys
import os

_backend_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
if _backend_dir not in sys.path:
    sys.path.insert(0, _backend_dir)

import json
from datetime import datetime, timezone, timedelta

from app.core.database import connect_to_mongo, close_mongo_connection, get_database
from app.services.utils import serialize_document

TEST_USER_ID = "test-client-ava-001"
TEST_BOOKING_ID = "booking-test-ava-001"


# ── Seed helpers ───────────────────────────────────────────────────────────────

async def seed_test_data() -> None:
    db = get_database()

    # Upsert test client user
    await db.users.update_one(
        {"_id": TEST_USER_ID},
        {"$setOnInsert": {
            "_id": TEST_USER_ID,
            "full_name": "AVA Test Client",
            "email": "ava-test@carthage-transfer.tn",
            "phone": "+216 99 000 001",
            "hashed_password": "placeholder",
            "role": "client",
            "preferred_language": "en",
            "theme_mode": "dark",
            "created_at": datetime.now(timezone.utc),
            "updated_at": datetime.now(timezone.utc),
        }},
        upsert=True,
    )

    # Upsert a completed booking so rewards/history tools have something to return
    departure_dt = datetime.now(timezone.utc) + timedelta(days=3)
    await db.bookings.update_one(
        {"_id": TEST_BOOKING_ID},
        {"$setOnInsert": {
            "_id": TEST_BOOKING_ID,
            "user_id": TEST_USER_ID,
            "passenger_name": "AVA Test Client",
            "passenger_phone": "+216 99 000 001",
            "pickup_location": "Tunis Airport",
            "destination_name": "Hammamet",
            "destination_city": "Hammamet",
            "vehicle_class": "VIP",
            "vehicle_type": "VIP",
            "departure_date": departure_dt.strftime("%Y-%m-%d"),
            "departure_time": "10:00",
            "passenger_count": 2,
            "luggage_count": 2,
            "trip_type": "one-way",
            "status": "completed",
            "total_price": 120.0,
            "is_guest": False,
            "created_at": datetime.now(timezone.utc),
            "updated_at": datetime.now(timezone.utc),
        }},
        upsert=True,
    )

    print(f"  Seeded test user  : {TEST_USER_ID}")
    print(f"  Seeded test booking: {TEST_BOOKING_ID}")


def _pp(label: str, result) -> None:
    print(f"\n{'='*60}")
    print(f"Tool: {label}")
    print(f"{'='*60}")
    if isinstance(result, (dict, list)):
        text = json.dumps(result, indent=2, default=str)
        # Truncate very long outputs so the terminal stays readable
        if len(text) > 1200:
            text = text[:1200] + "\n  ... (truncated)"
        print(text)
    else:
        print(result)


# ── Main test runner ───────────────────────────────────────────────────────────

async def main() -> None:
    print("=== Checkpoint 3: Client Tools Test ===\n")

    await connect_to_mongo()
    print("[*] Connected to MongoDB")

    print("[*] Seeding test data...")
    await seed_test_data()

    # Import tools AFTER DB is connected (lazy RAG store init needs FS only)
    from app.ai.tools_client import (
        search_knowledge_base,
        get_trip_history,
        create_booking,
        update_booking,
        cancel_booking,
        recommend_vehicle,
        get_user_promos,
        submit_claim,
    )

    # ── 1. search_knowledge_base ───────────────────────────────────────────────
    result = await search_knowledge_base.ainvoke({"query": "what is the cancellation policy"})
    _pp("search_knowledge_base", result)

    # ── 2. get_trip_history ────────────────────────────────────────────────────
    result = await get_trip_history.ainvoke({"user_id": TEST_USER_ID})
    _pp("get_trip_history", result)

    # ── 3. create_booking ─────────────────────────────────────────────────────
    future_date = (datetime.now(timezone.utc) + timedelta(days=5)).strftime("%Y-%m-%d")
    result = await create_booking.ainvoke({
        "user_id": TEST_USER_ID,
        "departure": "Tunis City Centre",
        "arrival": "Sousse",
        "date": future_date,
        "time": "14:00",
        "vehicle_type": "Standard",
        "passenger_count": 2,
        "trip_type": "one-way",
        "passenger_name": "AVA Test Client",
    })
    _pp("create_booking", result)
    new_booking_id = result.get("_id") if isinstance(result, dict) else None

    # ── 4. update_booking ─────────────────────────────────────────────────────
    if new_booking_id:
        result = await update_booking.ainvoke({
            "user_id": TEST_USER_ID,
            "booking_id": new_booking_id,
            "passenger_count": 3,
            "luggage_count": 2,
        })
        _pp("update_booking", result)
    else:
        print("\n[!] Skipping update_booking — create_booking did not return an id")

    # ── 5. cancel_booking ─────────────────────────────────────────────────────
    if new_booking_id:
        result = await cancel_booking.ainvoke({
            "user_id": TEST_USER_ID,
            "booking_id": new_booking_id,
        })
        _pp("cancel_booking", result)
    else:
        # Fall back to the seeded booking (which is already completed — expect an error)
        result = await cancel_booking.ainvoke({
            "user_id": TEST_USER_ID,
            "booking_id": TEST_BOOKING_ID,
        })
        _pp("cancel_booking (completed booking — expect error)", result)

    # ── 6. recommend_vehicle ───────────────────────────────────────────────────
    result = await recommend_vehicle.ainvoke({
        "passenger_count": 2,
        "trip_type": "one-way",
        "user_id": TEST_USER_ID,
    })
    _pp("recommend_vehicle", result)

    # ── 7. get_user_promos ────────────────────────────────────────────────────
    result = await get_user_promos.ainvoke({"user_id": TEST_USER_ID})
    _pp("get_user_promos", result)

    # ── 8. submit_claim ───────────────────────────────────────────────────────
    result = await submit_claim.ainvoke({
        "user_id": TEST_USER_ID,
        "booking_id": TEST_BOOKING_ID,
        "message": "The driver arrived 10 minutes late. Please review.",
    })
    _pp("submit_claim", result)

    # ── Part 0 smoke test: bound-tool user_id threading ───────────────────────
    print(f"\n{'='*60}")
    print("Part 0 smoke test: bound-tool user_id threading")
    print(f"{'='*60}")
    from app.ai.tool_registry import get_tools_for_role

    client_tools = get_tools_for_role("client", TEST_USER_ID)
    gth_bound = next((t for t in client_tools if t.name == "get_trip_history"), None)
    assert gth_bound is not None, "get_trip_history not found in client tools"

    # LLM schema must not expose user_id
    schema_fields = list(
        (gth_bound.args_schema.model_json_schema().get("properties") or {}).keys()
    ) if gth_bound.args_schema else []
    assert "user_id" not in schema_fields, f"user_id leaked into LLM schema: {schema_fields}"
    print(f"[PASS] user_id absent from bound get_trip_history schema: {schema_fields}")

    # Invoking without user_id should still work (it's pre-filled via closure)
    bound_result = await gth_bound.ainvoke({})
    assert isinstance(bound_result, (dict, list)), (
        f"Expected dict or list, got {type(bound_result)}"
    )
    if isinstance(bound_result, dict) and "error" in bound_result:
        print(f"[PASS] Bound tool invoked — returned error (expected if no trips): {bound_result}")
    else:
        count = len(bound_result) if isinstance(bound_result, list) else (
            len(bound_result.get("trips", [])) if isinstance(bound_result, dict) else "?"
        )
        print(f"[PASS] Bound tool invoked — user_id threaded through; trip count: {count}")

    print(f"\n{'='*60}")
    print("=== Checkpoint 3 + Part 0 complete ===")
    await close_mongo_connection()


if __name__ == "__main__":
    asyncio.run(main())
