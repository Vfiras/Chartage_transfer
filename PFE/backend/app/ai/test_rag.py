"""
Checkpoint 2 verification — run 3 sample queries against the built vector store
and print the top 3 chunks with similarity scores for each.

Usage:
    cd backend
    python app/ai/build_vectorstore.py   # build first if not done
    python app/ai/test_rag.py
"""
import sys
import os

_backend_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
if _backend_dir not in sys.path:
    sys.path.insert(0, _backend_dir)

from pathlib import Path
from langchain_huggingface import HuggingFaceEmbeddings
from langchain_chroma import Chroma

VECTORSTORE_DIR = Path(__file__).parent / "vectorstore"
EMBED_MODEL = "sentence-transformers/all-MiniLM-L6-v2"
COLLECTION_NAME = "carthage_transfer_kb"

QUERIES = [
    "what is the cancellation policy",
    "what is the night surcharge percentage",
    "tell me about the VIP vehicle",
]


def run():
    print("=== Checkpoint 2: RAG Query Test ===\n")

    if not VECTORSTORE_DIR.exists():
        print("ERROR: Vector store not found. Run build_vectorstore.py first.")
        sys.exit(1)

    print(f"Loading embeddings model: {EMBED_MODEL}")
    embeddings = HuggingFaceEmbeddings(model_name=EMBED_MODEL)

    print(f"Loading Chroma store from {VECTORSTORE_DIR}\n")
    store = Chroma(
        collection_name=COLLECTION_NAME,
        embedding_function=embeddings,
        persist_directory=str(VECTORSTORE_DIR),
    )

    for i, query in enumerate(QUERIES, 1):
        print("-" * 60)
        print(f"Query {i}: \"{query}\"")
        print("-" * 60)

        results = store.similarity_search_with_relevance_scores(query, k=3)
        for rank, (doc, score) in enumerate(results, 1):
            source = Path(doc.metadata.get("source", "unknown")).name
            snippet = doc.page_content.replace("\n", " ").strip()[:200]
            print(f"  [{rank}] score={score:.4f}  source={source}")
            print(f"       {snippet}...")
        print()

    print("=== Checkpoint 2 complete ===")


if __name__ == "__main__":
    run()
