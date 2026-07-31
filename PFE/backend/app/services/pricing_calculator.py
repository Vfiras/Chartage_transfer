"""
Real pricing engine — implements the Chauffeur Booking System formula used by
carthage-transfer.com, driven by each vehicle's `pricing` document
(see db/fleet_data.py).

Formula (distance-based transfer):
    total = initial_fee                     (return rate for return trips)
          + distance_km × per_km           (return rate for return trips)
          + n_waypoints × per_waypoint
          + waypoint_duration_mins × per_waypoint_duration_per_min

The hourly rate (per_hour) applies to HOURLY bookings, not distance transfers —
adding `duration × per_hour` on top of the per-km charge would double-bill a
normal transfer (a ~62 km Tunis→Hammamet on the Comfort Sedan must come to
≈ 12.98 + 62×0.413 ≈ 38.6 EUR, which matches the live site). Duration is still
measured and returned so the client can display an ETA.

Distance & duration come from the Google Directions API (MAPS_API_KEY); if the
call fails, a haversine × 1.3 road-factor fallback keeps the estimate usable.
"""
from __future__ import annotations

import math

import httpx

from app.core.config import settings

_DIRECTIONS_URL = "https://maps.googleapis.com/maps/api/directions/json"

_AVG_SPEED_KMH = 60.0   # fallback duration estimate
_ROAD_FACTOR = 1.3      # fallback: straight-line → road distance factor


def _haversine_km(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    r = 6371.0
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp = math.radians(lat2 - lat1)
    dl = math.radians(lng2 - lng1)
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * r * math.asin(math.sqrt(a))


async def get_route_metrics(
    pickup_lat: float,
    pickup_lng: float,
    destination_lat: float,
    destination_lng: float,
    waypoints: list[dict] | None = None,
) -> dict:
    """Return {distance_km, duration_hours, source} for the route.

    Tries the Google Directions API first (routes[0].legs summed, so waypoints
    are included in the driven distance); falls back to haversine × road factor.
    """
    if settings.maps_api_key:
        params = {
            "origin": f"{pickup_lat},{pickup_lng}",
            "destination": f"{destination_lat},{destination_lng}",
            "key": settings.maps_api_key,
        }
        if waypoints:
            params["waypoints"] = "|".join(
                f"{w['lat']},{w['lng']}" for w in waypoints if "lat" in w and "lng" in w
            )
        try:
            async with httpx.AsyncClient(timeout=8.0) as client:
                resp = await client.get(_DIRECTIONS_URL, params=params)
                data = resp.json()
            if data.get("status") == "OK" and data.get("routes"):
                legs = data["routes"][0]["legs"]
                meters = sum(leg["distance"]["value"] for leg in legs)
                seconds = sum(leg["duration"]["value"] for leg in legs)
                return {
                    "distance_km": round(meters / 1000.0, 2),
                    "duration_hours": round(seconds / 3600.0, 2),
                    "source": "google_directions",
                }
            print(f"[pricing] Directions API non-OK status: {data.get('status')} "
                  f"{data.get('error_message', '')}")
        except Exception as exc:  # noqa: BLE001 — network failure → fallback
            print(f"[pricing] Directions API call failed ({exc!r}); using haversine fallback")

    distance = _haversine_km(pickup_lat, pickup_lng, destination_lat, destination_lng)
    if waypoints:
        # Chain pickup → each waypoint → destination for a fair fallback estimate
        points = ([(pickup_lat, pickup_lng)]
                  + [(w["lat"], w["lng"]) for w in waypoints if "lat" in w and "lng" in w]
                  + [(destination_lat, destination_lng)])
        distance = sum(
            _haversine_km(points[i][0], points[i][1], points[i + 1][0], points[i + 1][1])
            for i in range(len(points) - 1)
        )
    distance_km = round(distance * _ROAD_FACTOR, 2)
    return {
        "distance_km": distance_km,
        "duration_hours": round(distance_km / _AVG_SPEED_KMH, 2),
        "source": "haversine_fallback",
    }


def calculate_price(
    vehicle: dict,
    distance_km: float,
    duration_hours: float | None = None,
    trip_type: str = "one_way",
    waypoints: list[dict] | None = None,
) -> dict:
    """Compute the full price breakdown for one vehicle.

    `vehicle` is a cars-collection document. Vehicles missing the `pricing`
    object (legacy docs) fall back to base_price as a flat initial fee.
    """
    pricing = vehicle.get("pricing") or {}
    is_return = str(trip_type).lower().replace("-", "_") in ("return", "round_trip", "roundtrip")

    initial = float(pricing.get("initial_fee_return" if is_return else "initial_fee",
                                vehicle.get("base_price", 0.0)) or 0.0)
    per_km = float(pricing.get("per_km_return" if is_return else "per_km", 0.0) or 0.0)
    per_waypoint = float(pricing.get("per_waypoint", 0.0) or 0.0)
    per_wp_min = float(pricing.get("per_waypoint_duration_per_min", 0.0) or 0.0)

    if duration_hours is None:
        duration_hours = round(distance_km / _AVG_SPEED_KMH, 2)

    waypoints = waypoints or []
    wp_minutes = sum(float(w.get("duration_mins", 0) or 0) for w in waypoints)

    # Return trips drive the route twice; the return per-km rate in the source
    # data equals the one-way rate, so the doubling happens on distance.
    billed_km = distance_km * 2 if is_return else distance_km

    distance_cost = round(billed_km * per_km, 2)
    waypoint_cost = round(len(waypoints) * per_waypoint, 2)
    waypoint_duration_cost = round(wp_minutes * per_wp_min, 2)
    total = round(initial + distance_cost + waypoint_cost + waypoint_duration_cost, 2)

    return {
        "vehicle_id": vehicle.get("_id") or vehicle.get("id"),
        "vehicle_name": vehicle.get("name"),
        "category": vehicle.get("category"),
        "trip_type": "return" if is_return else "one_way",
        "distance_km": distance_km,
        "billed_km": round(billed_km, 2),
        "duration_hours": duration_hours,
        "currency": pricing.get("currency", "EUR"),
        "breakdown": {
            "initial_fee": round(initial, 2),
            "distance_cost": distance_cost,
            "waypoint_cost": waypoint_cost,
            "waypoint_duration_cost": waypoint_duration_cost,
        },
        "total_eur": total,
    }
