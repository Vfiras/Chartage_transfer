from datetime import datetime, timezone
from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException

from app.core.database import get_database
from app.core.deps import require_admin
from app.schemas.dtos import SupplierCreate, SupplierStatusUpdate, SupplierUpdate
from app.services.utils import serialize_document

router = APIRouter()


@router.get("/")
async def list_suppliers(_: dict = Depends(require_admin)) -> dict:
    db = get_database()
    suppliers: list[dict] = []
    async for doc in db.suppliers.find({}).sort([("name", 1)]):
        suppliers.append(serialize_document(doc) or {})
    return {"suppliers": suppliers}


@router.post("/")
async def create_supplier(
    payload: SupplierCreate,
    _: dict = Depends(require_admin),
) -> dict:
    now = datetime.now(timezone.utc)
    document = {
        "_id": f"sup-{uuid4().hex}",
        **payload.model_dump(),
        "created_at": now,
        "updated_at": now,
    }
    db = get_database()
    await db.suppliers.insert_one(document)
    return {"supplier": serialize_document(document)}


@router.put("/{supplier_id}")
async def update_supplier(
    supplier_id: str,
    payload: SupplierUpdate,
    _: dict = Depends(require_admin),
) -> dict:
    db = get_database()
    update = {k: v for k, v in payload.model_dump().items() if v is not None}
    if not update:
        raise HTTPException(status_code=400, detail="No fields to update")
    update["updated_at"] = datetime.now(timezone.utc)
    result = await db.suppliers.update_one({"_id": supplier_id}, {"$set": update})
    if result.matched_count == 0:
        raise HTTPException(status_code=404, detail="Supplier not found")
    doc = await db.suppliers.find_one({"_id": supplier_id})
    return {"supplier": serialize_document(doc)}


@router.patch("/{supplier_id}/status")
async def toggle_supplier_status(
    supplier_id: str,
    payload: SupplierStatusUpdate,
    _: dict = Depends(require_admin),
) -> dict:
    if payload.status not in ("active", "inactive"):
        raise HTTPException(status_code=400, detail="Status must be 'active' or 'inactive'")
    db = get_database()
    result = await db.suppliers.update_one(
        {"_id": supplier_id},
        {"$set": {"status": payload.status, "updated_at": datetime.now(timezone.utc)}},
    )
    if result.matched_count == 0:
        raise HTTPException(status_code=404, detail="Supplier not found")
    doc = await db.suppliers.find_one({"_id": supplier_id})
    return {"supplier": serialize_document(doc)}


@router.delete("/{supplier_id}")
async def delete_supplier(
    supplier_id: str,
    _: dict = Depends(require_admin),
) -> dict:
    db = get_database()
    result = await db.suppliers.delete_one({"_id": supplier_id})
    if result.deleted_count == 0:
        raise HTTPException(status_code=404, detail="Supplier not found")
    return {"deleted": True}
