from datetime import datetime, timezone
from uuid import uuid4

from fastapi import APIRouter

from app.core.database import get_database
from app.schemas.dtos import DestinationCreate
from app.services.destination_service import create_destination, list_destinations
from app.services.utils import serialize_document

router = APIRouter()

# Seed data migrated from Flutter destination_guide_repository.dart
_DEFAULT_RECOMMENDATIONS = [
    {
        "_id": "rec-1",
        "category": "restaurant",
        "name": "Cafe de la Plage",
        "city": "Bizerte",
        "region": "Ras Jbal",
        "image_url": "https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=1200&q=80",
        "rating": 4.6,
        "price_range": "$$",
        "tags": ["Sea View", "Breakfast", "Coffee"],
        "description": "Relaxed seaside breakfast and lunch spot with a tourist-friendly menu and fast service.",
        "notes": "Great for guests arriving early. Quiet terrace, English menu, card payment accepted.",
        "phone": "+216 20 123 456",
        "opening_hours": "Open 07:00 - 22:00",
        "primary_label": "Food Type",
        "primary_value": "Seafood & Cafe",
        "secondary_label": "View",
        "secondary_value": "Sea View",
        "tertiary_label": "Specialty",
        "tertiary_value": "Breakfast plates",
        "featured": True,
        "visible": True,
    },
    {
        "_id": "rec-2",
        "category": "hotel",
        "name": "Dar Zmen Boutique Hotel",
        "city": "Bizerte",
        "region": "Ras Jbal",
        "image_url": "https://images.unsplash.com/photo-1542314831-068cd1dbfeeb?auto=format&fit=crop&w=1200&q=80",
        "rating": 4.4,
        "price_range": "$$$",
        "tags": ["Family", "Business", "Parking"],
        "description": "Boutique stay with clean service, premium rooms, and easy access for transfer guests.",
        "notes": "Recommended for families and business guests. Ask for late check-in when needed.",
        "phone": "+216 21 555 111",
        "opening_hours": "24/7 Reception",
        "primary_label": "Stars",
        "primary_value": "4-Star",
        "secondary_label": "Amenities",
        "secondary_value": "Wi-Fi, Parking",
        "tertiary_label": "Audience",
        "tertiary_value": "Family / Business",
        "featured": True,
        "visible": True,
    },
    {
        "_id": "rec-3",
        "category": "cafe",
        "name": "The Blue Coffee",
        "city": "Bizerte",
        "region": "Ras Jbal",
        "image_url": "https://images.unsplash.com/photo-1509042239860-f550ce710b93?auto=format&fit=crop&w=1200&q=80",
        "rating": 4.3,
        "price_range": "$",
        "tags": ["Desserts", "Quiet", "Coffee"],
        "description": "A calm coffee stop with panoramic views and a comfortable atmosphere for couples.",
        "notes": "Ideal for short breaks after airport transfers or before a city tour.",
        "phone": "+216 28 901 234",
        "opening_hours": "08:00 - 23:00",
        "primary_label": "Type",
        "primary_value": "Specialty Cafe",
        "secondary_label": "View",
        "secondary_value": "City / Sea",
        "tertiary_label": "Best for",
        "tertiary_value": "Coffee & desserts",
        "featured": False,
        "visible": True,
    },
    {
        "_id": "rec-4",
        "category": "activity",
        "name": "Cap Blanc Sunset Walk",
        "city": "Bizerte",
        "region": "Cap Blanc",
        "image_url": "https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=1200&q=80",
        "rating": 4.8,
        "price_range": "Free",
        "tags": ["Nature", "Family", "Sunset"],
        "description": "Short scenic walk with excellent sunset views and photo opportunities.",
        "notes": "Recommend for tourists who want a simple activity after a long drive.",
        "phone": "+216 22 000 450",
        "opening_hours": "Best at 17:00 - 20:00",
        "primary_label": "Activity",
        "primary_value": "Scenic walk",
        "secondary_label": "Duration",
        "secondary_value": "1 - 2 hours",
        "tertiary_label": "Audience",
        "tertiary_value": "Family / Couples",
        "featured": True,
        "visible": True,
    },
    {
        "_id": "rec-5",
        "category": "restaurant",
        "name": "Dar El Jeld Restaurant",
        "city": "Tunis",
        "region": "Medina",
        "image_url": "https://images.unsplash.com/photo-1414235077428-338989a2e8c0?auto=format&fit=crop&w=1200&q=80",
        "rating": 4.9,
        "price_range": "$$$",
        "tags": ["Fine Dining", "Historic", "Local Cuisine"],
        "description": "Premium Tunisian dining experience for tourists looking for a memorable dinner.",
        "notes": "Best recommended for premium guests and evening city trips.",
        "phone": "+216 70 010 010",
        "opening_hours": "12:00 - 23:30",
        "primary_label": "Food Type",
        "primary_value": "Traditional Tunisian",
        "secondary_label": "View",
        "secondary_value": "Historic courtyard",
        "tertiary_label": "Specialty",
        "tertiary_value": "Lamb & couscous",
        "featured": False,
        "visible": True,
    },
    {
        "_id": "rec-6",
        "category": "hotel",
        "name": "La Badira Hammamet",
        "city": "Hammamet",
        "region": "Yasmine",
        "image_url": "https://images.unsplash.com/photo-1566073771259-6a8506099945?auto=format&fit=crop&w=1200&q=80",
        "rating": 4.7,
        "price_range": "$$$$",
        "tags": ["Luxury", "Beach", "Couples"],
        "description": "Luxury beachfront stay with premium service and elegant interiors.",
        "notes": "Strong recommendation for couples and VIP guests heading to the coast.",
        "phone": "+216 72 123 000",
        "opening_hours": "24/7 Reception",
        "primary_label": "Stars",
        "primary_value": "5-Star",
        "secondary_label": "Amenities",
        "secondary_value": "Spa, Pool, Beach",
        "tertiary_label": "Audience",
        "tertiary_value": "Couples / VIP",
        "featured": False,
        "visible": True,
    },
]


async def _ensure_recommendations() -> None:
    db = get_database()
    count = await db.recommendations.count_documents({})
    if count == 0:
        now = datetime.now(timezone.utc)
        for rec in _DEFAULT_RECOMMENDATIONS:
            doc = dict(rec)
            doc["created_at"] = now
            await db.recommendations.insert_one(doc)


# ─── Existing destinations endpoints ──────────────────────────────────────────

@router.get("/")
async def get_destinations() -> dict:
    items = await list_destinations()
    return {"items": items, "total": len(items)}


@router.post("/")
async def add_destination(payload: DestinationCreate) -> dict:
    destination = await create_destination(payload.model_dump())
    return {"destination": destination}


# ─── Recommendations endpoint ──────────────────────────────────────────────────

@router.get("/recommendations/")
async def get_recommendations(
    city: str | None = None,
    category: str | None = None,
) -> dict:
    await _ensure_recommendations()
    db = get_database()
    query: dict = {"visible": True}
    if city:
        query["city"] = {"$regex": city, "$options": "i"}
    if category:
        query["category"] = category.lower()

    items: list[dict] = []
    async for doc in db.recommendations.find(query).sort([("rating", -1)]):
        items.append(serialize_document(doc) or {})
    return {"items": items, "total": len(items)}


@router.post("/recommendations/")
async def add_recommendation(payload: dict) -> dict:
    db = get_database()
    now = datetime.now(timezone.utc)
    doc = {
        "_id": f"rec-{uuid4().hex}",
        **payload,
        "visible": payload.get("visible", True),
        "featured": payload.get("featured", False),
        "created_at": now,
    }
    await db.recommendations.insert_one(doc)
    return {"recommendation": serialize_document(doc)}
