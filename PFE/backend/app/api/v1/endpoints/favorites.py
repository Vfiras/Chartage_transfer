from datetime import datetime, timezone
from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException

from app.core.deps import require_client
from app.core.database import get_database
from app.schemas.dtos import FavoriteLocationCreate
from app.services.utils import serialize_document

router = APIRouter()


@router.get("/")
async def list_favorites(current_user: dict = Depends(require_client)) -> dict:
    db = get_database()
    favorites: list[dict] = []
    async for favorite in db.favorites.find({"user_id": current_user["_id"]}).sort([("created_at", -1)]):
        favorites.append(serialize_document(favorite) or {})
    return {"favorites": favorites}


@router.post("/")
async def create_favorite(
    payload: FavoriteLocationCreate,
    current_user: dict = Depends(require_client),
) -> dict:
    now = datetime.now(timezone.utc)
    document = {
        "_id": f"fav-{uuid4().hex}",
        "user_id": current_user["_id"],
        "label": payload.label.strip(),
        "address": payload.address.strip(),
        "type": payload.type.strip() or "custom",
        "created_at": now,
        "updated_at": now,
    }
    db = get_database()
    await db.favorites.insert_one(document)
    return {"favorite": serialize_document(document)}


@router.delete("/{favorite_id}")
async def delete_favorite(
    favorite_id: str,
    current_user: dict = Depends(require_client),
) -> dict:
    db = get_database()
    result = await db.favorites.delete_one({"_id": favorite_id, "user_id": current_user["_id"]})
    if result.deleted_count != 1:
        raise HTTPException(status_code=404, detail="Favorite not found")
    return {"deleted": True}
