from functools import lru_cache
from pathlib import Path

from pydantic import AliasChoices, Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "Carthage Transfer API"
    environment: str = "development"
    api_v1_prefix: str = "/api/v1"
    mongodb_uri: str = "mongodb://localhost:27017"
    mongodb_db: str = "carthage_transfer"
    jwt_secret_key: str  # required — no default, must be set in .env
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 60 * 24 * 7  # 7 days
    allowed_origins: str = "http://localhost:3000,http://localhost:8080"
    media_root: str = str(Path(__file__).resolve().parents[2] / "uploads")
    media_url_prefix: str = "/media"
    smtp_host: str = ""
    smtp_port: int = 587
    smtp_user: str = ""
    smtp_pass: str = Field(
        "", validation_alias=AliasChoices("SMTP_PASS", "SMTP_PASSWORD")
    )
    from_email: str = Field(
        "", validation_alias=AliasChoices("FROM_EMAIL", "SMTP_FROM")
    )
    app_base_url: str = "http://localhost:8000"
    openai_api_key: str = ""
    google_api_key: str = ""
    # Declared so the backend's strict Settings (extra=forbid) accepts the key the
    # Flutter app uses for Google Maps. The backend itself does not consume it.
    maps_api_key: str = ""

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
