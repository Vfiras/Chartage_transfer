## Task 1a — Real vehicle seed
Status: DONE
Evidence: `python run_seed.py` → `cars: 8`. Collection now holds car-economy, car-comfort-sedan, car-minivan, car-large-van, car-minibus, car-e-class, car-s-class, car-v-class — each with the full `pricing` object from the PDFs, capacities from the live-site fleet guide (vehicles.txt), `order` from WP, and back-compat fields (`base_price` = initial_fee, `seats`, `luggage`). Single source of truth: `backend/app/db/fleet_data.py` (shared by seed.py and cars.py bootstrap).
Known gaps: Economy seeded with truncated-PDF values, `pricing_verified: false` (see Task 0 flag).

## Task 1b — Pricing calculator + Directions API
Status: DONE
Evidence (real Google Directions API response, Tunis-Carthage Airport → Hammamet):
```
Route metrics: {"distance_km": 73.53, "duration_hours": 1.02, "source": "google_directions"}
Comfort Sedan one-way: initial 12.98 + 73.53 km × 0.413 = 30.37 → total 43.35 EUR
Comfort Sedan return : initial 25.96 + 147.06 km × 0.413 = 60.74 → total 86.70 EUR
VERDICT: PASS
```
Note: the task predicted 38–40 EUR assuming 60–65 km; Google's actual road route (A1 via Hammamet interchange) is 73.53 km, so the correct total is 43.35 EUR. The formula matches the prediction exactly at the predicted distance (12.98 + 62×0.413 = 38.6). Haversine×1.3 fallback covers Directions outages.
