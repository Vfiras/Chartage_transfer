"""
Build (or rebuild) the Chroma vector store from the knowledge/ directory.

Usage:
    cd backend
    python app/ai/build_vectorstore.py

Rerunning this script at any time safely rebuilds the store from whatever
.txt files are currently in knowledge/ — no code changes required.

STALENESS GUARD
---------------
Each build records a manifest (source_manifest.json) holding a SHA-256 of every
knowledge/*.txt file it was built from.  At backend startup, check_vectorstore_
freshness() compares the current files against that manifest and logs a loud,
non-blocking warning if anything changed since the last build — so a missed
rebuild can never again silently serve stale RAG answers.
"""
import sys
import os
import shutil
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path

_backend_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
if _backend_dir not in sys.path:
    sys.path.insert(0, _backend_dir)

KNOWLEDGE_DIR = Path(__file__).parent / "knowledge"
VECTORSTORE_DIR = Path(__file__).parent / "vectorstore"
MANIFEST_PATH = VECTORSTORE_DIR / "source_manifest.json"
EMBED_MODEL = "sentence-transformers/all-MiniLM-L6-v2"
COLLECTION_NAME = "carthage_transfer_kb"


# ---------------------------------------------------------------------------
# Staleness guard — lightweight (hashlib/json only, NO heavy ML imports), so it
# is safe to call on every backend startup.
# ---------------------------------------------------------------------------

def _file_sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _current_knowledge_hashes() -> dict:
    return {p.name: _file_sha256(p) for p in sorted(KNOWLEDGE_DIR.glob("*.txt"))}


def write_manifest() -> None:
    """Record the hash of every knowledge file the index was just built from."""
    manifest = {
        "built_at": datetime.now(timezone.utc).isoformat(),
        "embed_model": EMBED_MODEL,
        "collection": COLLECTION_NAME,
        "files": _current_knowledge_hashes(),
    }
    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print(f"  Wrote source manifest: {MANIFEST_PATH.name} "
          f"({len(manifest['files'])} files hashed)")


def check_vectorstore_freshness() -> list:
    """Compare current knowledge/*.txt hashes against what the index was built from.

    Returns a list of human-readable issue strings (empty list = in sync).
    Never raises, never rebuilds, never blocks — it only reports, so a missed
    rebuild can't silently serve stale RAG answers (the bug this guards against).
    """
    issues: list = []

    if not MANIFEST_PATH.exists():
        return ["vector store has no build manifest — cannot verify freshness; "
                "run build_vectorstore.py to (re)build and record one."]

    try:
        manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError) as exc:
        return [f"could not read the vector store manifest ({exc}); consider rebuilding."]

    built = manifest.get("files", {})
    current = _current_knowledge_hashes()

    for name, cur_hash in current.items():
        if name not in built:
            issues.append(f"knowledge/{name} is NEW since the index was last built")
        elif built[name] != cur_hash:
            issues.append(f"knowledge/{name} has CHANGED since the index was last built")
    for name in built:
        if name not in current:
            issues.append(f"knowledge/{name} was REMOVED since the index was last built")

    # An embedding-model change also invalidates every stored vector.
    built_model = manifest.get("embed_model")
    if built_model and built_model != EMBED_MODEL:
        issues.append(f"embedding model changed ({built_model} -> {EMBED_MODEL})")

    return issues


def log_freshness_on_startup() -> None:
    """Loud, non-blocking startup report on whether the RAG index is current."""
    import logging
    log = logging.getLogger("carthage.rag")

    issues = check_vectorstore_freshness()
    if not issues:
        log.info("[RAG] vector store is in sync with knowledge/ files.")
        print("[RAG] vector store is in sync with knowledge/ files.")
        return

    banner = "!" * 72
    lines = [
        banner,
        "RAG VECTOR STORE MAY BE STALE — answers could cite outdated/removed policy.",
        *[f"  - {it}" for it in issues],
        "  Fix: cd backend && python app/ai/build_vectorstore.py, then restart the backend.",
        banner,
    ]
    for ln in lines:
        log.warning(ln)
        print(ln, file=sys.stderr)


# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------

def build():
    # Heavy ML imports are LAZY (inside build) so importing this module at
    # backend startup for the freshness check stays cheap.
    from langchain_community.document_loaders import TextLoader
    from langchain_text_splitters import RecursiveCharacterTextSplitter
    from langchain_huggingface import HuggingFaceEmbeddings
    from langchain_chroma import Chroma

    print("=== Building Chroma vector store ===\n")

    # ── 1. Wipe existing store so rebuild is always clean ─────────────────────
    if VECTORSTORE_DIR.exists():
        shutil.rmtree(VECTORSTORE_DIR)
        print(f"  Removed existing store at {VECTORSTORE_DIR}")
    VECTORSTORE_DIR.mkdir(parents=True)

    # ── 2. Load all .txt files from knowledge/ ────────────────────────────────
    txt_files = sorted(KNOWLEDGE_DIR.glob("*.txt"))
    if not txt_files:
        raise FileNotFoundError(f"No .txt files found in {KNOWLEDGE_DIR}")

    print(f"  Loading {len(txt_files)} knowledge file(s):")
    docs = []
    for path in txt_files:
        loader = TextLoader(str(path), encoding="utf-8")
        loaded = loader.load()
        print(f"    {path.name} — {len(loaded)} document(s)")
        docs.extend(loaded)

    # ── 3. Chunk ──────────────────────────────────────────────────────────────
    splitter = RecursiveCharacterTextSplitter(chunk_size=500, chunk_overlap=50)
    chunks = splitter.split_documents(docs)
    print(f"\n  Split into {len(chunks)} chunk(s) (chunk_size=500, overlap=50)")

    # ── 4. Embed & persist ────────────────────────────────────────────────────
    print(f"\n  Loading embedding model: {EMBED_MODEL}")
    embeddings = HuggingFaceEmbeddings(model_name=EMBED_MODEL)

    print(f"  Embedding and persisting to {VECTORSTORE_DIR} ...")
    Chroma.from_documents(
        documents=chunks,
        embedding=embeddings,
        collection_name=COLLECTION_NAME,
        persist_directory=str(VECTORSTORE_DIR),
    )

    # ── 5. Record the source manifest for the staleness guard ─────────────────
    write_manifest()

    print(f"\n=== Done — {len(chunks)} chunks indexed ===")


if __name__ == "__main__":
    build()
