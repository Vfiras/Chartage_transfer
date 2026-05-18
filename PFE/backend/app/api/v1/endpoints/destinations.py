from fastapi import APIRouter

from app.schemas.dtos import DestinationCreate
from app.services.destination_service import create_destination, list_destinations

router = APIRouter()


@router.get("/")
async def get_destinations() -> dict:
    items = await list_destinations()
    return {"items": items, "total": len(items)}


@router.post("/")
async def add_destination(payload: DestinationCreate) -> dict:
    destination = await create_destination(payload.model_dump())
    return {"destination": destination}
