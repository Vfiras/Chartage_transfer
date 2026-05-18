from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

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

    @app.on_event("shutdown")
    async def shutdown_event() -> None:
        await close_mongo_connection()

    app.include_router(api_router, prefix=settings.api_v1_prefix)

    @app.get("/health", tags=["health"])
    async def health_check() -> dict[str, str]:
        return {"status": "ok", "service": settings.app_name}

    return app


app = create_app()
