"""
Checkpoint 4 verification — tests the role-gated tool registry.

Checks:
  1. Client role returns exactly 8 tools with correct names.
  2. Admin role returns 17 tools (8 client + 9 admin).
  3. No admin-only tool name appears in the client tool list  ← assertion.
  4. user_id is NOT in the LLM-facing schema of any bound client tool.

No database connection needed — registry setup is pure Python.
"""
import sys
import os

_backend_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
if _backend_dir not in sys.path:
    sys.path.insert(0, _backend_dir)

from app.ai.tool_registry import get_tools_for_role
from app.ai.tools_admin import ADMIN_TOOLS

ADMIN_TOOL_NAMES = {t.name for t in ADMIN_TOOLS}
EXPECTED_CLIENT_COUNT = 8
EXPECTED_ADMIN_TOOL_COUNT = 9

print("=== Checkpoint 4: Tool Registry Test ===\n")

# ── Client role ────────────────────────────────────────────────────────────────
client_tools = get_tools_for_role("client", "test-user-1")
client_names  = [t.name for t in client_tools]

print(f"Client tools ({len(client_tools)}):")
for t in client_tools:
    # Also show whether user_id appears in the LLM schema
    schema_fields = list((t.args_schema.model_json_schema().get("properties") or {}).keys()) if t.args_schema else []
    uid_exposed = "user_id" in schema_fields
    flag = "  [WARNING: user_id in schema!]" if uid_exposed else ""
    print(f"  - {t.name:<30} schema fields: {schema_fields}{flag}")

# ── Admin role ─────────────────────────────────────────────────────────────────
admin_tools = get_tools_for_role("admin", "test-admin-1")
admin_names  = [t.name for t in admin_tools]

print(f"\nAdmin tools ({len(admin_tools)}):")
for t in admin_tools:
    marker = " [ADMIN-ONLY]" if t.name in ADMIN_TOOL_NAMES else ""
    print(f"  - {t.name}{marker}")

# ── Assertions ─────────────────────────────────────────────────────────────────
print("\n--- Assertions ---")

# 1. Client count
assert len(client_tools) == EXPECTED_CLIENT_COUNT, (
    f"Expected {EXPECTED_CLIENT_COUNT} client tools, got {len(client_tools)}"
)
print(f"[PASS] Client tool count == {EXPECTED_CLIENT_COUNT}")

# 2. Admin count
expected_admin_total = EXPECTED_CLIENT_COUNT + EXPECTED_ADMIN_TOOL_COUNT
assert len(admin_tools) == expected_admin_total, (
    f"Expected {expected_admin_total} admin tools, got {len(admin_tools)}"
)
print(f"[PASS] Admin tool count  == {expected_admin_total} ({EXPECTED_CLIENT_COUNT} client + {EXPECTED_ADMIN_TOOL_COUNT} admin-only)")

# 3. No admin-only tool name in client list  ← the required assertion
overlap = ADMIN_TOOL_NAMES & set(client_names)
assert not overlap, (
    f"Admin tool(s) found in client list: {overlap}"
)
print(f"[PASS] No admin-only tool names appear in the client list")

# 4. user_id not exposed in any bound client tool schema
for t in client_tools:
    if t.args_schema:
        fields = list((t.args_schema.model_json_schema().get("properties") or {}).keys())
        assert "user_id" not in fields, (
            f"user_id is exposed in schema for tool '{t.name}': {fields}"
        )
print(f"[PASS] user_id is not exposed in any client tool LLM schema")

# 5. ValueError on unknown role
try:
    get_tools_for_role("superuser", "x")
    assert False, "Should have raised ValueError"
except ValueError as e:
    print(f"[PASS] Unknown role raises ValueError: {e}")

print("\n=== Checkpoint 4 complete ===")
