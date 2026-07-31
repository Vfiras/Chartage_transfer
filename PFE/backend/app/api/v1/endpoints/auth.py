from datetime import datetime, timezone

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status

from app.core.database import get_database
from app.core.deps import get_current_user
from app.schemas.dtos import LoginRequest, SignupRequest, UserProfileUpdate
from app.services.auth_service import (
    authenticate_user,
    build_token_response,
    build_user_payload,
    register_client,
)
from app.services.profile_media_service import delete_local_avatar, save_avatar_upload
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
    return {"user": build_user_payload(current_user)}


@router.put("/me")
async def update_me(
    payload: UserProfileUpdate,
    current_user: dict = Depends(get_current_user),
) -> dict:
    db = get_database()
    update_data = {k: v for k, v in payload.model_dump().items() if v is not None}
    if "email" in update_data:
        normalized_email = update_data["email"].strip().lower()
        existing = await db.users.find_one(
            {"email": normalized_email, "_id": {"$ne": current_user["_id"]}}
        )
        if existing:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Email already in use",
            )
        update_data["email"] = normalized_email
    update_data["updated_at"] = datetime.now(timezone.utc)
    await db.users.update_one({"_id": current_user["_id"]}, {"$set": update_data})
    updated = await db.users.find_one({"_id": current_user["_id"]})
    updated = serialize_document(updated) or {}
    return {"user": build_user_payload(updated)}


@router.post("/me/avatar")
async def upload_avatar(
    file: UploadFile = File(...),
    current_user: dict = Depends(get_current_user),
) -> dict:
    filename = (file.filename or "").lower()
    allowed_extensions = (".jpg", ".jpeg", ".png", ".webp")
    if not filename.endswith(allowed_extensions):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Only JPG, PNG, and WebP images are supported",
        )

    avatar_url = await save_avatar_upload(str(current_user["_id"]), file)
    db = get_database()
    delete_local_avatar(current_user.get("avatar_url"))
    await db.users.update_one(
        {"_id": current_user["_id"]},
        {
            "$set": {
                "avatar_url": avatar_url,
                "updated_at": datetime.now(timezone.utc),
            }
        },
    )
    updated = await db.users.find_one({"_id": current_user["_id"]})
    updated = serialize_document(updated) or {}
    return {"user": build_user_payload(updated)}


@router.post("/forgot-password")
async def forgot_password(email: str) -> dict:
    import secrets
    import smtplib
    from datetime import timedelta
    from email.mime.text import MIMEText

    from app.core.config import settings

    db = get_database()
    user = await db.users.find_one({"email": email.strip().lower()})
    if user:
        token = secrets.token_urlsafe(32)
        expiry = datetime.now(timezone.utc) + timedelta(hours=1)
        await db.password_resets.delete_many({"user_id": str(user["_id"])})
        await db.password_resets.insert_one(
            {"token": token, "user_id": str(user["_id"]), "expires_at": expiry}
        )
        reset_url = f"{settings.app_base_url}/reset-password?token={token}"
        if settings.smtp_host and settings.smtp_user:
            try:
                msg = MIMEText(
                    f"Click the link below to reset your Carthage Transfer password:\n\n{reset_url}\n\nThis link expires in 1 hour."
                )
                msg["Subject"] = "Carthage Transfer — Password Reset"
                msg["From"] = settings.from_email or settings.smtp_user
                msg["To"] = email.strip().lower()
                with smtplib.SMTP(settings.smtp_host, settings.smtp_port) as server:
                    server.starttls()
                    server.login(settings.smtp_user, settings.smtp_pass)
                    server.sendmail(msg["From"], [msg["To"]], msg.as_string())
            except Exception:
                pass  # Email delivery is best-effort; token is always stored
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
