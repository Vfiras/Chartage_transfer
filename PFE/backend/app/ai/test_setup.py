"""
Checkpoint 1 verification — import every new AI package and check API keys are set.
"""
import sys
import os

# Allow running from any working directory — backend/ must be on sys.path
_backend_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
if _backend_dir not in sys.path:
    sys.path.insert(0, _backend_dir)

print("=== Checkpoint 1: Setup & Environment ===\n")

# ── 1. Package imports ────────────────────────────────────────────────────────
from importlib.metadata import version as pkg_version, PackageNotFoundError

def check_pkg(import_name: str, dist_name: str):
    try:
        __import__(import_name)
        try:
            v = pkg_version(dist_name)
        except PackageNotFoundError:
            v = "(version unknown)"
        print(f"  {dist_name:<30} {v}")
    except ImportError as e:
        print(f"  FAILED {dist_name}: {e}")

print("[1/3] Importing packages...")
check_pkg("langchain",            "langchain")
check_pkg("langgraph",            "langgraph")
check_pkg("langchain_openai",     "langchain-openai")
check_pkg("langchain_google_genai","langchain-google-genai")
check_pkg("chromadb",             "chromadb")
check_pkg("sentence_transformers","sentence-transformers")

# ── 2. Settings load ──────────────────────────────────────────────────────────
print("\n[2/3] Loading settings from config...")
try:
    from app.core.config import settings
    print(f"  Settings loaded OK — app: {settings.app_name!r}, env: {settings.environment!r}")
except Exception as e:
    print(f"  FAILED to load settings: {e}")
    sys.exit(1)

# ── 3. API key presence check (no values printed) ─────────────────────────────
print("\n[3/3] Checking AI API keys...")
openai_set = bool(settings.openai_api_key)
google_set = bool(settings.google_api_key)
print(f"  OPENAI_API_KEY   : {'SET' if openai_set else 'NOT SET'}")
print(f"  GOOGLE_API_KEY   : {'SET' if google_set else 'NOT SET (required — AVA routes all requests to Gemini)'}")

print("\n=== Checkpoint 1 complete ===")
