from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.api.v1.api import api_router
from app.core.config import settings
from app.core.database import close_mongo_connection, connect_to_mongo
from app.db.indexes import ensure_indexes


def create_app() -> FastAPI:
    app = FastAPI(
        title=settings.app_name,
        description="Carthage Transfer — transport booking platform API",
        version="1.0.0",
    )

    allowed_origins = [o.strip() for o in settings.allowed_origins.split(",") if o.strip()]

    app.add_middleware(
        CORSMiddleware,
        allow_origins=allowed_origins,
        allow_credentials=True,
        allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
        allow_headers=["Authorization", "Content-Type", "Accept"],
    )

    @app.on_event("startup")
    async def startup_event() -> None:
        await connect_to_mongo()
        await ensure_indexes()
        from app.ai.build_vectorstore import log_freshness_on_startup
        log_freshness_on_startup()
        if not settings.google_api_key:
            print(
                "\nWARNING: GOOGLE_API_KEY not set — AVA will fail for all requests.\n"
            )

    @app.on_event("shutdown")
    async def shutdown_event() -> None:
        await close_mongo_connection()

    media_root = Path(settings.media_root)
    media_root.mkdir(parents=True, exist_ok=True)
    app.mount(settings.media_url_prefix, StaticFiles(directory=media_root), name="media")

    app.include_router(api_router, prefix=settings.api_v1_prefix)

    @app.get("/health", tags=["health"])
    async def health_check() -> dict[str, str]:
        return {"status": "ok", "service": settings.app_name}

    return app


app = create_app()
