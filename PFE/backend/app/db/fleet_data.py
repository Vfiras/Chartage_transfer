"""
Real Carthage Transfer fleet — extracted from the live site's WordPress
"Chauffeur Booking System" vehicle pages (8 PDFs, July 2026).

Single source of truth for vehicle seed data: used by db/seed.py and by
cars.py's empty-collection bootstrap so the two can never drift.

Pricing model (per vehicle, EUR):
  initial_fee / initial_fee_return   flat value added to the order sum
  per_km / per_km_return             price per kilometre of the trip
  per_hour                           price per hour (hourly bookings)
  per_extra_hour                     price per hour of extra waiting time
  per_waypoint                       flat fee per intermediate stop
  per_waypoint_duration_per_min      price per minute spent at a waypoint

Capacities come from the fleet guide (ai/knowledge/vehicles.txt, same site).

⚠ "Economy" (WP post 9136): the source PDF renders its price fields truncated
  ("12.", "0.3", …) — exact decimals unrecoverable. Seeded with the visible
  digits and pricing_verified=False; correct via the admin Pricing screen.
"""

REAL_FLEET: list[dict] = [
    {
        "_id": "car-economy",
        "name": "Economy",
        "model": "Toyota Yaris",
        "category": "economy",
        "seats": 3,
        "luggage": 3,
        "order": 2,
        "base_price": 12.0,  # = pricing.initial_fee (kept for back-compat sort/display)
        "availability": True,
        "image_url": "assets/images/fleet/toyota-hiris.webp",
        "pricing_verified": False,  # ⚠ source PDF truncated — see module docstring
        "pricing": {
            "currency": "EUR",
            "initial_fee": 12.0,
            "initial_fee_return": 25.0,
            "per_km": 0.30,
            "per_km_return": 0.30,
            "per_hour": 14.0,
            "per_extra_hour": 16.0,
            "per_waypoint": 15.0,
            "per_waypoint_duration_per_min": 0.10,
        },
        "features": ["Private Transfer", "Air Conditioning", "1 Hour of Free Waiting Time"],
    },
    {
        "_id": "car-comfort-sedan",
        "name": "Comfort Sedan",
        "model": "Comfort sedan",
        "category": "comfort",
        "seats": 4,
        "luggage": 4,
        "order": 2,
        "base_price": 12.98,
        "availability": True,
        "image_url": "assets/images/fleet/Renault-Express-Minivan-Transfers-Tunisia.webp",
        "pricing_verified": True,
        "pricing": {
            "currency": "EUR",
            "initial_fee": 12.98,
            "initial_fee_return": 25.96,
            "per_km": 0.413,
            "per_km_return": 0.413,
            "per_hour": 14.16,
            "per_extra_hour": 16.52,
            "per_waypoint": 20.06,
            "per_waypoint_duration_per_min": 0.118,
        },
        "features": ["Private Transfer", "Air Conditioning", "1 Hour of Free Waiting Time"],
    },
    {
        "_id": "car-minivan",
        "name": "Minivan",
        "model": "Minivan",
        "category": "minivan",
        "seats": 4,
        "luggage": 8,
        "order": 4,
        "base_price": 17.7,
        "availability": True,
        "image_url": "assets/images/fleet/Premium-8-Seaters-Van-Transfers-Tunisia.webp",
        "pricing_verified": True,
        "pricing": {
            "currency": "EUR",
            "initial_fee": 17.7,
            "initial_fee_return": 35.4,
            "per_km": 0.4956,
            "per_km_return": 0.4956,
            "per_hour": 23.6,
            "per_extra_hour": 23.6,
            "per_waypoint": 20.06,
            "per_waypoint_duration_per_min": 0.059,
        },
        "features": ["Private Transfer", "Air Conditioning", "1 Hour of Free Waiting Time"],
    },
    {
        "_id": "car-large-van",
        "name": "Large Van",
        "model": "Large van",
        "category": "van",
        "seats": 7,
        "luggage": 14,
        "order": 5,
        "base_price": 29.5,
        "availability": True,
        "image_url": "assets/images/fleet/Toyota-Hiace-Transfers-Tunisia.webp",
        "pricing_verified": True,
        "pricing": {
            "currency": "EUR",
            "initial_fee": 29.5,
            "initial_fee_return": 59.0,
            "per_km": 0.5192,
            "per_km_return": 0.5192,
            "per_hour": 5.9,
            "per_extra_hour": 5.9,
            "per_waypoint": 23.6,
            "per_waypoint_duration_per_min": 0.059,
        },
        "features": ["Private Transfer", "Air Conditioning", "1 Hour of Free Waiting Time"],
    },
    {
        "_id": "car-minibus",
        "name": "Minibus",
        "model": "Minibus",
        "category": "minibus",
        "seats": 12,
        "luggage": 16,
        "order": 5,
        "base_price": 47.2,
        "availability": True,
        "image_url": "assets/images/fleet/Toyota-Coaster-Transfers-Tunisia.webp",
        "pricing_verified": True,
        "pricing": {
            "currency": "EUR",
            "initial_fee": 47.2,
            "initial_fee_return": 94.4,
            "per_km": 0.649,
            "per_km_return": 0.649,
            "per_hour": 23.6,
            "per_extra_hour": 23.6,
            "per_waypoint": 47.2,
            "per_waypoint_duration_per_min": 0.05,
        },
        "features": [
            "Private Transfer", "Air Conditioning",
            "1 Hour of Free Waiting Time", "Free Cancellation (24h)",
        ],
    },
    {
        "_id": "car-e-class",
        "name": "Mercedes E Class - Business",
        "model": "Mercedes E Class",
        "category": "business",
        "seats": 4,
        "luggage": 6,
        "order": 7,
        "base_price": 90.86,
        "availability": True,
        "image_url": "assets/images/fleet/mercedes-e-class-2024-carthage-transfer.webp",
        "pricing_verified": True,
        "pricing": {
            "currency": "EUR",
            "initial_fee": 90.86,
            "initial_fee_return": 181.72,
            "per_km": 1.357,
            "per_km_return": 1.357,
            "per_hour": 34.22,
            "per_extra_hour": 47.2,
            "per_waypoint": 29.5,
            "per_waypoint_duration_per_min": 0.118,
        },
        "features": ["Private Transfer", "Air Conditioning", "1 Hour of Free Waiting Time"],
    },
    {
        "_id": "car-s-class",
        "name": "Mercedes S Class 2024 - Royalty",
        "model": "Mercedes S Class 2024",
        "category": "luxury",
        "seats": 3,
        "luggage": 6,
        "order": 7,
        "base_price": 354.0,
        "availability": True,
        "image_url": "assets/images/fleet/premium-sedan-2024-carthage-transfer.webp",
        "pricing_verified": True,
        "pricing": {
            "currency": "EUR",
            "initial_fee": 354.0,
            "initial_fee_return": 708.0,
            "per_km": 2.006,
            "per_km_return": 2.006,
            "per_hour": 82.6,
            "per_extra_hour": 0.0,
            "per_waypoint": 38.94,
            "per_waypoint_duration_per_min": 0.0,
        },
        "features": ["Private Transfer", "Air Conditioning", "1 Hour of Free Waiting Time"],
    },
    {
        "_id": "car-v-class",
        "name": "Mercedes V Class - Executive",
        "model": "Mercedes V Class",
        "category": "executive",
        "seats": 6,
        "luggage": 12,
        "order": 8,
        "base_price": 112.1,
        "availability": True,
        "image_url": "assets/images/fleet/Mercedes-V-Class-Vip-Transfers-Tunisia.webp",
        "pricing_verified": True,
        "pricing": {
            "currency": "EUR",
            "initial_fee": 112.1,
            "initial_fee_return": 224.2,
            # Site lists "per km (return, new ride)" as 0.00 — treated as a
            # data-entry gap; the one-way/return rate is used for all variants.
            "per_km": 1.534,
            "per_km_return": 1.534,
            "per_hour": 54.87,
            "per_extra_hour": 59.0,
            "per_waypoint": 29.5,
            "per_waypoint_duration_per_min": 0.118,
        },
        "features": ["Private Transfer", "Air Conditioning", "1 Hour of Free Waiting Time"],
    },
]

# All categories present in the real fleet + the legacy 4-bucket model, so
# existing bookings/screens created under the old scheme keep validating.
VALID_CATEGORIES: frozenset[str] = frozenset({
    "economy", "comfort", "minivan", "van", "minibus",
    "business", "luxury", "executive",
    # legacy buckets
    "Standard", "VIP", "Van", "Luxury",
})
