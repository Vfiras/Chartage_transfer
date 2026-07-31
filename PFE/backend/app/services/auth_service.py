from datetime import datetime, timezone
from uuid import uuid4

from app.core.database import get_database
from app.core.security import create_access_token, get_password_hash, verify_password
from app.services.utils import serialize_document


async def authenticate_user(user: dict | None, password: str) -> dict | None:
    if not user:
        return None
    if not verify_password(password, user["hashed_password"]):
        return None
    return user


def build_token_response(user: dict) -> dict:
    return {
        "access_token": create_access_token(str(user["_id"])),
        "token_type": "bearer",
        "role": user["role"],
        "user": build_user_payload(user),
    }


def build_user_payload(user: dict) -> dict:
    return {
        "id": str(user["_id"]),
        "name": user.get("full_name", ""),
        "full_name": user.get("full_name", ""),
        "email": user.get("email", ""),
        "phone": user.get("phone", ""),
        "role": user.get("role", ""),
        "preferred_language": user.get("preferred_language", "en"),
        "theme_mode": user.get("theme_mode", "dark"),
        "avatar_url": user.get("avatar_url"),
    }


async def register_client(payload: dict) -> dict:
    db = get_database()
    email = payload["email"].strip().lower()
    existing = await db.users.find_one({"email": email})
    if existing:
        raise ValueError("Account already exists")
    now = datetime.now(timezone.utc)
    user = {
        "_id": f"user-{uuid4().hex}",
        "email": email,
        "full_name": payload["full_name"].strip(),
        "phone": (payload.get("phone") or "").strip(),
        "role": "client",
        "hashed_password": get_password_hash(payload["password"]),
        "preferred_language": "en",
        "theme_mode": "dark",
        "is_active": True,
        "created_at": now,
        "updated_at": now,
    }
    # Referral code is issued at signup so the user can share it immediately.
    from app.services.rewards_service import (
        generate_referral_code,
        grant_welcome_promo,
    )
    user["referral_code"] = generate_referral_code(user["full_name"])
    user["referral_credits"] = 0.0
    await db.users.insert_one(user)
    # Every new account gets a one-time 10% welcome offer.
    await grant_welcome_promo(user["_id"])
    return build_token_response(user)
