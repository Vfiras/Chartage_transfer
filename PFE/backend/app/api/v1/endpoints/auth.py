from fastapi import APIRouter, Depends, HTTPException, status

from app.core.database import get_database
from app.core.deps import get_current_user
from app.schemas.dtos import LoginRequest, SignupRequest, UserProfileUpdate
from app.services.auth_service import authenticate_user, build_token_response, register_client
from app.services.utils import serialize_document

router = APIRouter()


@router.post("/login")
async def login(payload: LoginRequest) -> dict:
    db = get_database()
    user = await db.users.find_one({"email": payload.email.strip().lower()})
    if user and "_id" in user:
        user["_id"] = str(user["_id"])
    authenticated = await authenticate_user(user, payload.password)
    if not authenticated:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials")
    return build_token_response(authenticated)


@router.post("/signup")
async def signup(payload: SignupRequest) -> dict:
    try:
        return await register_client(payload.model_dump())
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(exc)) from exc


@router.get("/me")
async def get_me(current_user: dict = Depends(get_current_user)) -> dict:
    return {
        "user": {
            "id": current_user["_id"],
            "full_name": current_user.get("full_name", ""),
            "email": current_user.get("email", ""),
            "phone": current_user.get("phone", ""),
            "role": current_user.get("role", ""),
            "preferred_language": current_user.get("preferred_language", "en"),
            "theme_mode": current_user.get("theme_mode", "dark"),
            "avatar_url": current_user.get("avatar_url"),
        }
    }


@router.put("/me")
async def update_me(
    payload: UserProfileUpdate,
    current_user: dict = Depends(get_current_user),
) -> dict:
    from datetime import datetime, timezone
    db = get_database()
    update_data = {k: v for k, v in payload.model_dump().items() if v is not None}
    update_data["updated_at"] = datetime.now(timezone.utc)
    await db.users.update_one({"_id": current_user["_id"]}, {"$set": update_data})
    updated = await db.users.find_one({"_id": current_user["_id"]})
    updated = serialize_document(updated) or {}
    return {
        "user": {
            "id": updated["_id"],
            "full_name": updated.get("full_name", ""),
            "email": updated.get("email", ""),
            "phone": updated.get("phone", ""),
            "role": updated.get("role", ""),
            "preferred_language": updated.get("preferred_language", "en"),
            "theme_mode": updated.get("theme_mode", "dark"),
            "avatar_url": updated.get("avatar_url"),
        }
    }


@router.post("/forgot-password")
async def forgot_password(email: str) -> dict:
    # In production: generate a reset token, send email
    # For PFE: return success without revealing if email exists
    db = get_database()
    _ = await db.users.find_one({"email": email.strip().lower()})
    return {"message": "If an account exists for this email, a reset link has been sent."}


@router.post("/reset-password")
async def reset_password(token: str, new_password: str) -> dict:
    # In production: validate token from DB, update password
    # For PFE demo: stub response
    from app.core.security import get_password_hash
    from datetime import datetime, timezone
    db = get_database()
    reset_doc = await db.password_resets.find_one({"token": token})
    if not reset_doc:
        raise HTTPException(status_code=400, detail="Invalid or expired reset token")
    await db.users.update_one(
        {"_id": reset_doc["user_id"]},
        {"$set": {"hashed_password": get_password_hash(new_password), "updated_at": datetime.now(timezone.utc)}},
    )
    await db.password_resets.delete_one({"token": token})
    return {"message": "Password updated successfully"}
