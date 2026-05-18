from datetime import datetime, timezone
from uuid import uuid4

from app.core.database import get_database
from app.services.utils import serialize_document


async def list_destinations() -> list[dict]:
    db = get_database()
    items: list[dict] = []
    async for item in db.destinations.find({}).sort([("city", 1), ("region", 1)]):
        items.append(serialize_document(item) or {})
    return items


async def create_destination(payload: dict) -> dict:
    db = get_database()
    destination_id = f"dest-{uuid4().hex}"
    document = {
        "_id": destination_id,
        **payload,
        "visible": payload.get("visible", True),
        "created_at": datetime.now(timezone.utc),
        "updated_at": datetime.now(timezone.utc),
    }
    await db.destinations.insert_one(document)
    return serialize_document(document) or {}
