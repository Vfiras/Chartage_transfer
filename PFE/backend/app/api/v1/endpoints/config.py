from fastapi import APIRouter

from app.core.database import get_database

router = APIRouter()

_DEFAULT_CITIES = [
    "Tunis-Carthage Airport (TUN)",
    "Tunis-Carthage International Airport",
    "Tunis City Centre",
    "La Marsa",
    "Sidi Bou Said",
    "Hammamet",
    "Sousse",
    "Monastir Airport",
    "Djerba Airport",
    "Sfax",
    "Nabeul",
    "Tunis Gare Centrale",
    "Hotel du Lac",
    "Carthage Archaeological Site",
    "Bardo Museum",
    "Medina de Tunis",
    "Les Berges du Lac",
    "El Menzah",
    "Ariana",
    "Ben Arous",
    "Manouba",
]


@router.get("/cities")
async def get_cities() -> dict:
    db = get_database()
    count = await db.cities.count_documents({})
    if count == 0:
        await db.cities.insert_many(
            [{"_id": f"city-{i}", "name": c} for i, c in enumerate(_DEFAULT_CITIES)]
        )
    cities: list[str] = []
    async for doc in db.cities.find({}).sort([("name", 1)]):
        cities.append(doc["name"])
    return {"cities": cities}


@router.post("/cities")
async def add_city(name: str) -> dict:
    db = get_database()
    from uuid import uuid4
    doc = {"_id": f"city-{uuid4().hex}", "name": name.strip()}
    await db.cities.insert_one(doc)
    return {"city": doc}
