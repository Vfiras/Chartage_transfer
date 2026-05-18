from pydantic import BaseModel, EmailStr


class LoginRequest(BaseModel):
    email: str
    password: str


class SignupRequest(BaseModel):
    full_name: str
    email: str
    phone: str | None = None
    password: str


class UserProfileUpdate(BaseModel):
    full_name: str | None = None
    phone: str | None = None
    preferred_language: str | None = None
    theme_mode: str | None = None
    avatar_url: str | None = None


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    role: str
    user: dict | None = None


class DriverStatusUpdate(BaseModel):
    status: str


class TripCreate(BaseModel):
    driver_id: str | None = None
    user_id: str | None = None
    passenger_name: str
    passenger_phone: str | None = None
    pickup_location: str | None = None
    destination_name: str
    destination_city: str | None = None
    vehicle_type: str | None = None
    estimated_earnings: float = 0
    pickup_time: str | None = None
    eta_minutes: int = 12
    trip_type: str | None = "one-way"
    departure_date: str | None = None
    departure_time: str | None = None
    return_date: str | None = None
    return_time: str | None = None
    passenger_count: int | None = None
    luggage_count: int | None = None
    promo_code: str | None = None
    dynamic_surcharge: float | None = None
    discount_amount: float | None = None
    guest_email: str | None = None
    guest_phone: str | None = None
    contact_email: str | None = None
    contact_phone: str | None = None
    vehicle_class: str | None = None
    total_price: float | None = None
    is_guest: bool = False


class TripUpdate(BaseModel):
    driver_id: str | None = None
    user_id: str | None = None
    passenger_name: str | None = None
    passenger_phone: str | None = None
    pickup_location: str | None = None
    destination_name: str | None = None
    destination_city: str | None = None
    vehicle_type: str | None = None
    estimated_earnings: float | None = None
    pickup_time: str | None = None
    eta_minutes: int | None = None
    status: str | None = None
    trip_type: str | None = None
    departure_date: str | None = None
    departure_time: str | None = None
    return_date: str | None = None
    return_time: str | None = None
    passenger_count: int | None = None
    luggage_count: int | None = None
    promo_code: str | None = None
    dynamic_surcharge: float | None = None
    discount_amount: float | None = None
    guest_email: str | None = None
    guest_phone: str | None = None
    contact_email: str | None = None
    contact_phone: str | None = None
    vehicle_class: str | None = None
    total_price: float | None = None
    is_guest: bool | None = None


class ChatRequest(BaseModel):
    message: str


class TripAssign(BaseModel):
    driver_id: str


class TripStatusUpdate(BaseModel):
    status: str


class PromoValidationRequest(BaseModel):
    code: str
    subtotal: float


class FavoriteLocationCreate(BaseModel):
    label: str
    address: str
    type: str = "custom"


class RecommendationCreate(BaseModel):
    destination_id: str
    city: str
    region: str
    name: str
    category: str
    rating: float = 0.0
    visible: bool = True
    description: str | None = None
    image_url: str | None = None
    price_range: str | None = None
    tags: list[str] = []
    notes: str | None = None
    phone: str | None = None
    opening_hours: str | None = None
    primary_label: str | None = None
    primary_value: str | None = None
    secondary_label: str | None = None
    secondary_value: str | None = None
    tertiary_label: str | None = None
    tertiary_value: str | None = None
    featured: bool = False


class RecommendationUpdate(BaseModel):
    destination_id: str | None = None
    city: str | None = None
    region: str | None = None
    name: str | None = None
    category: str | None = None
    rating: float | None = None
    visible: bool | None = None
    description: str | None = None
    image_url: str | None = None
    price_range: str | None = None
    tags: list[str] | None = None
    notes: str | None = None
    phone: str | None = None
    opening_hours: str | None = None
    primary_label: str | None = None
    primary_value: str | None = None
    secondary_label: str | None = None
    secondary_value: str | None = None
    tertiary_label: str | None = None
    tertiary_value: str | None = None
    featured: bool | None = None


class AnalyticsResponse(BaseModel):
    active_drivers: int
    total_trips: int
    destination_popularity: list[dict]
    recommendation_usage: list[dict]


class DestinationCreate(BaseModel):
    name: str
    city: str
    region: str
    description: str | None = None
    visible: bool = True


class SupplierCreate(BaseModel):
    name: str
    phone: str
    email: EmailStr
    handle: str | None = None
    status: str = "active"


class SupplierUpdate(BaseModel):
    name: str | None = None
    phone: str | None = None
    email: EmailStr | None = None
    handle: str | None = None
    status: str | None = None


class SupplierStatusUpdate(BaseModel):
    status: str


# ─── Car schemas ───────────────────────────────────────────────────────────────

class CarCreate(BaseModel):
    name: str
    model: str
    category: str
    seats: int
    luggage: int
    base_price: float
    availability: bool = True
    image_url: str | None = None


class CarUpdate(BaseModel):
    name: str | None = None
    model: str | None = None
    category: str | None = None
    seats: int | None = None
    luggage: int | None = None
    base_price: float | None = None
    availability: bool | None = None
    image_url: str | None = None


# ─── Promotion schemas ─────────────────────────────────────────────────────────

class PromotionCreate(BaseModel):
    code: str
    discount_type: str = "percentage"
    value: float
    expiry_date: str | None = None
    usage_limit: int = 100
    active: bool = True


class PromotionUpdate(BaseModel):
    code: str | None = None
    discount_type: str | None = None
    value: float | None = None
    expiry_date: str | None = None
    usage_limit: int | None = None
    active: bool | None = None


# ─── Pricing rules schema ──────────────────────────────────────────────────────

class NightPricingConfig(BaseModel):
    enabled: bool
    start_time: str = "22:00"
    end_time: str = "06:00"
    percentage: float = 30


class LastMinutePricingConfig(BaseModel):
    enabled: bool
    within_hours: int = 24
    percentage: float = 20


class WeekendPricingConfig(BaseModel):
    enabled: bool
    percentage: float = 10


class SeasonalPricingConfig(BaseModel):
    enabled: bool
    percentage: float = 0


class PricingRulesUpdate(BaseModel):
    minimum_booking_hours: int | None = None
    modification_limit_hours: int | None = None
    cancellation_limit_hours: int | None = None
    night_pricing: NightPricingConfig | None = None
    last_minute_pricing: LastMinutePricingConfig | None = None
    weekend_pricing: WeekendPricingConfig | None = None
    seasonal_pricing: SeasonalPricingConfig | None = None
