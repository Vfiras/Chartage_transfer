"""
Model router tests — flat Gemini-only routing.

Section A: Routing table (no network calls)
  - All task_type x role combinations must route to CLOUD_PRIMARY.
  - No LOCAL tier exists anymore.

Section B: Cloud tier status
  - CLOUD_PRIMARY is ChatGoogleGenerativeAI(gemini-2.5-flash), gated on GOOGLE_API_KEY.
  - CLOUD_FALLBACK is None (no second provider configured).

Section C: Regression — admin and client both go to CLOUD_PRIMARY
  - C1: get_model(any_task, "admin") is CLOUD_PRIMARY (identity check)
  - C2: get_model(any_task, "client") is CLOUD_PRIMARY (identity check, was LOCAL before)
  - C3: CLOUD_PRIMARY is Gemini (not None when key is set)
"""

import asyncio
import sys
import os

_backend_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
if _backend_dir not in sys.path:
    sys.path.insert(0, _backend_dir)

from app.ai.model_router import (
    CLOUD_PRIMARY,
    CLOUD_FALLBACK,
    get_model,
    invoke_with_fallback,
    _tier_name,
)
from app.core.config import settings

print("=== Model Router Test (Gemini-only) ===\n")

# ── Section A: Routing table (no network) ─────────────────────────────────────
print("-- Section A: Routing table --\n")

routing_cases = [
    # (task_type,               role,     expected_tier)
    ("intent_classification",   "client", "CLOUD_PRIMARY"),
    ("rag_answer",              "client", "CLOUD_PRIMARY"),
    ("simple_response",         "client", "CLOUD_PRIMARY"),
    ("synthesis",               "client", "CLOUD_PRIMARY"),
    ("booking_assistance",      "client", "CLOUD_PRIMARY"),
    ("general",                 "client", "CLOUD_PRIMARY"),
    ("fleet_management",        "admin",  "CLOUD_PRIMARY"),
    ("intent_classification",   "admin",  "CLOUD_PRIMARY"),
]

all_a_pass = True
for task_type, role, expected in routing_cases:
    model = get_model(task_type, role)
    name = _tier_name(model)
    ok = model is CLOUD_PRIMARY
    status = "[PASS]" if ok else "[FAIL]"
    if not ok:
        all_a_pass = False
    print(f"  {status} task={task_type!r:<28} role={role!r:<8} -> {name}")

print()
if all_a_pass:
    print("[PASS] All Section A routing assertions passed\n")
else:
    print("[FAIL] Some Section A routing assertions failed\n")

# ── Section B: Cloud tier status ──────────────────────────────────────────────
print("-- Section B: Cloud tier status --\n")
print("  CLOUD_PRIMARY  (Gemini)  :", "CONFIGURED (gemini-2.5-flash)" if CLOUD_PRIMARY else "NOT configured (set GOOGLE_API_KEY in .env)")
print("  CLOUD_FALLBACK           : None (no second provider configured)")
print()

# ── Section C: Regression — flat routing confirmed ────────────────────────────
print("-- Section C: Regression test --\n")

admin_task_cases = [
    "intent_classification",
    "rag_answer",
    "fleet_management",
    "general",
]
client_task_cases = [
    "intent_classification",
    "rag_answer",
    "simple_response",
    "synthesis",
    "booking_assistance",
]

print("C1 get_model(task, 'admin') must always be CLOUD_PRIMARY:\n")
all_c1_pass = True
for task in admin_task_cases:
    model = get_model(task, "admin")
    ok = model is CLOUD_PRIMARY
    if not ok:
        all_c1_pass = False
    print(f"  {'[PASS]' if ok else '[FAIL]'} task={task!r:<28} is CLOUD_PRIMARY={ok}")

print()
if all_c1_pass:
    print("  [PASS] All C1 admin routing assertions passed\n")
else:
    print("  [FAIL] Some C1 admin routing assertions failed\n")

print("C2 get_model(task, 'client') must always be CLOUD_PRIMARY (was LOCAL before):\n")
all_c2_pass = True
for task in client_task_cases:
    model = get_model(task, "client")
    ok = model is CLOUD_PRIMARY
    if not ok:
        all_c2_pass = False
    print(f"  {'[PASS]' if ok else '[FAIL]'} task={task!r:<28} is CLOUD_PRIMARY={ok}")

print()
if all_c2_pass:
    print("  [PASS] All C2 client routing assertions passed\n")
else:
    print("  [FAIL] Some C2 client routing assertions failed\n")

print("C3 CLOUD_PRIMARY identity + type check:\n")
c3_pass = False
if CLOUD_PRIMARY is not None:
    is_gemini = "gemini" in type(CLOUD_PRIMARY).__name__.lower() or "google" in type(CLOUD_PRIMARY).__name__.lower()
    if is_gemini:
        print(f"  [PASS] CLOUD_PRIMARY is {type(CLOUD_PRIMARY).__name__}")
        c3_pass = True
    else:
        print(f"  [FAIL] CLOUD_PRIMARY is {type(CLOUD_PRIMARY).__name__} — expected Gemini type")
else:
    print("  [SKIP] CLOUD_PRIMARY is None (GOOGLE_API_KEY not set) — verifying RuntimeError fires...")


    async def _check_no_key() -> None:
        await invoke_with_fallback([("human", "hello")], "general", "client")

    try:
        asyncio.run(_check_no_key())
        print("  [FAIL] No exception raised — should have raised RuntimeError")
    except RuntimeError as e:
        if "GOOGLE_API_KEY" in str(e):
            print(f"  [PASS] RuntimeError fired correctly (no key): {e}")
            c3_pass = True
        else:
            print(f"  [FAIL] Wrong RuntimeError message: {e}")

print()
all_c_pass = all_c1_pass and all_c2_pass and c3_pass
print("[PASS] Section C complete — flat routing confirmed" if all_c_pass else
      "[FAIL] Section C found failures")

print()
print("=== Model Router Test complete ===")
