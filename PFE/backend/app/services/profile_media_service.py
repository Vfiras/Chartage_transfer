from pathlib import Path
from uuid import uuid4

from fastapi import UploadFile

from app.core.config import settings


def media_root() -> Path:
    root = Path(settings.media_root)
    root.mkdir(parents=True, exist_ok=True)
    return root


def avatar_directory() -> Path:
    directory = media_root() / "avatars"
    directory.mkdir(parents=True, exist_ok=True)
    return directory


def avatar_relative_url(filename: str) -> str:
    return f"{settings.media_url_prefix}/avatars/{filename}"


async def save_avatar_upload(user_id: str, file: UploadFile) -> str:
    suffix = Path(file.filename or "").suffix.lower()
    if suffix not in {".jpg", ".jpeg", ".png", ".webp"}:
        suffix = ".jpg"

    filename = f"{user_id}-{uuid4().hex}{suffix}"
    destination = avatar_directory() / filename
    content = await file.read()
    destination.write_bytes(content)
    return avatar_relative_url(filename)


def delete_local_avatar(relative_url: str | None) -> None:
    if not relative_url or not relative_url.startswith(f"{settings.media_url_prefix}/"):
        return
    relative_path = relative_url.removeprefix(f"{settings.media_url_prefix}/")
    path = media_root() / relative_path
    if path.exists():
        path.unlink()
