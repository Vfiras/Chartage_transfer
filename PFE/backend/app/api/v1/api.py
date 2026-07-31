from fastapi import APIRouter

from app.api.v1.endpoints import (
    admin,
    analytics,
    assistant,
    auth,
    bookings,
    cars,
    complaints,
    config,
    destinations,
    favorites,
    notifications,
    pricing,
    promotions,
    rewards,
    suppliers,
)

api_router = APIRouter()
api_router.include_router(auth.router, prefix="/auth", tags=["auth"])
api_router.include_router(assistant.router, prefix="/assistant", tags=["assistant"])
api_router.include_router(bookings.router, prefix="/bookings", tags=["bookings"])
api_router.include_router(cars.router, prefix="/cars", tags=["cars"])
api_router.include_router(pricing.router, prefix="/pricing", tags=["pricing"])
api_router.include_router(promotions.router, prefix="/promotions", tags=["promotions"])
api_router.include_router(favorites.router, prefix="/favorites", tags=["favorites"])
api_router.include_router(destinations.router, prefix="/destinations", tags=["destinations"])
api_router.include_router(analytics.router, prefix="/analytics", tags=["analytics"])
api_router.include_router(admin.router, prefix="/admin", tags=["admin"])
api_router.include_router(notifications.router, prefix="/notifications", tags=["notifications"])
api_router.include_router(suppliers.router, prefix="/suppliers", tags=["suppliers"])
api_router.include_router(rewards.router, prefix="/rewards", tags=["rewards"])
api_router.include_router(config.router, prefix="/config", tags=["config"])
api_router.include_router(complaints.router, prefix="/complaints", tags=["complaints"])
