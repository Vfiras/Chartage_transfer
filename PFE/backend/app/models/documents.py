from datetime import datetime
from enum import StrEnum

from pydantic import BaseModel, EmailStr, Field


class UserRole(StrEnum):
    admin = "admin"
    driver = "driver"
    client = "client"


class DriverStatus(StrEnum):
    active = "active"
    suspended = "suspended"
    offline = "offline"
    online = "online"


class TripStatus(StrEnum):
    requested = "requested"
    accepted = "accepted"
    in_progress = "in_progress"
    completed = "completed"
    cancelled = "cancelled"


class RecommendationCategory(StrEnum):
    restaurant = "restaurant"
    hotel = "hotel"
    cafe = "cafe"
    activity = "activity"
    attraction = "attraction"
    food_place = "food_place"
    premium_location = "premium_location"


class BaseDocument(BaseModel):
    id: str | None = Field(default=None, alias="_id")
    created_at: datetime | None = None
    updated_at: datetime | None = None


class UserDocument(BaseDocument):
    email: EmailStr
    full_name: str
    role: UserRole
    hashed_password: str
    is_active: bool = True


class DriverDocument(BaseDocument):
    user_id: str
    phone: str | None = None
    license_number: str | None = None
    vehicle_plate: str | None = None
    status: DriverStatus = DriverStatus.offline
    rating: float = Field(default=0.0, ge=0.0, le=5.0)
    total_trips: int = 0


class TripDocument(BaseDocument):
    driver_id: str
    passenger_name: str
    destination_name: str
    destination_city: str | None = None
    status: TripStatus = TripStatus.requested
    eta_minutes: int = Field(default=0, ge=0)
    started_at: datetime | None = None
    ended_at: datetime | None = None


class RecommendationDocument(BaseDocument):
    destination_id: str
    city: str
    region: str
    name: str
    category: RecommendationCategory
    rating: float = Field(default=0.0, ge=0.0, le=5.0)
    visible: bool = True
    description: str | None = None


class DestinationDocument(BaseDocument):
    name: str
    city: str
    region: str
    description: str | None = None
    visible: bool = True


class RestaurantDocument(BaseDocument):
    destination_id: str
    city: str
    region: str
    name: str
    rating: float = Field(default=0.0, ge=0.0, le=5.0)
    cuisine_type: str | None = None
    price_range: str | None = None
    view_type: str | None = None
    specialties: list[str] = Field(default_factory=list)
    opening_hours: str | None = None
    phone: str | None = None
    notes: str | None = None
    visible: bool = True


class HotelDocument(BaseDocument):
    destination_id: str
    city: str
    region: str
    name: str
    stars: int = Field(default=3, ge=1, le=5)
    rating: float = Field(default=0.0, ge=0.0, le=5.0)
    price_range: str | None = None
    amenities: list[str] = Field(default_factory=list)
    tags: list[str] = Field(default_factory=list)
    phone: str | None = None
    notes: str | None = None
    visible: bool = True


class ActivityDocument(BaseDocument):
    destination_id: str
    city: str
    region: str
    name: str
    activity_type: str | None = None
    duration: str | None = None
    price: str | None = None
    audience: str | None = None
    notes: str | None = None
    visible: bool = True
