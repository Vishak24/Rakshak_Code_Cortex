# Feature Engineering

17 features feed the XGBoost model (`FEATURE_ORDER` in
`backend/lambdas/_shared/rakshak_common.py`, matching
`feature_columns` in `ml/train_chennai_risk_model.py`). This document
explains how each group was constructed and why — see `DATASET_CARD.md`
for what the underlying data is and isn't.

## Geographic engineering

- `latitude`, `longitude`, `pincode` — real Chennai coordinates and postal
  codes, not synthetic. 44 zones total: the original 20 from
  `generate_chennai_synthetic_datav2.py`'s hand-curated area table, plus 24
  more from `Finaldataset.py`'s `ALL_44` dict, chosen to cover every
  pincode the backend actually serves (matched against
  `assets/chennai_zones.geojson`'s 64 mapped polygons — the model covers
  the 44 zones with a defined risk baseline; the geojson covers more
  polygons purely for map rendering).
- `area_encoded`, `neighborhood_encoded` — `sklearn.LabelEncoder` over the
  area/neighborhood name strings. Encoders are persisted
  (`label_encoder_area.pkl`, `label_encoder_neighborhood.pkl`) so
  inference uses the exact same integer mapping as training.
- **Latitude-band risk heuristic** (`Finaldataset.py`): `lat >= 13.10 →
  high`, `lat >= 13.05 → medium`, else `low`. This is a simple, explicit
  proxy for "North Chennai reads as higher-density in local context" —
  chosen because it was inspectable and defensible for a demo, not because
  it's a validated geographic risk model. A real deployment would replace
  this with actual incident density per zone.

## Temporal engineering

Derived from `occurrence_time`:

| Feature | Derivation |
|---|---|
| `hour`, `day_of_week` | direct from timestamp |
| `is_weekend` | `day_of_week >= 5` |
| `is_night` | `hour >= 22 or hour <= 5` |
| `is_evening` | `18 <= hour <= 22` (v1 generator) / `17 <= hour <= 21` (v2 extension) |
| `is_rush_hour` | `8-10` or `17-20` (v1) / `hour in {8,9,17,18,19}` (v2) |

The occurrence-hour distribution itself is not uniform: in
higher-`base_risk` areas, the v1 generator weights 40% of events into
20:00–24:00 and 30% of the remainder into 00:00–06:00 — encoding the
domain assumption that risk concentrates at night in less-safe areas, a
pattern grounded in general public-safety literature (see `DATASET_CARD.md`
"Domain grounding"), not measured from real Chennai data.

## Patrol-coverage / response engineering

The two features the project's own prior submission materials specifically
called out as genuine domain-insight feature engineering, not artifacts of
any external dataset:

- `reporting_delay_minutes` — time between an incident occurring and being
  reported. Scaled by area risk tier (higher-risk areas get a wider,
  slower delay distribution: 5–45 min vs. 1–10 min in low-risk areas) —
  encoding the real-world pattern that reporting friction itself correlates
  with area safety perception.
- `response_time_minutes` — each area has an `avg_police_response_min`
  baseline, adjusted by a time-of-day multiplier (`1.2×` at night,
  `1.3×` during rush hour) and randomized `±20–40%`, clipped to `[3, 45]`
  minutes.
- `total_resolution_time_minutes` — `reporting_delay + response_time`, a
  direct composite.

These are genuine feature-engineering decisions (choosing *what* to encode
and *how* to scale it), independent of whichever dataset they're computed
over — the same logic would apply unchanged if real response-time data
became available.

## Hotspot engineering

- `signal_count_last_7d`, `signal_count_last_30d` — Poisson-sampled around
  a per-area base rate (`base_risk * 60 * 0.15` for 7-day,
  `base_risk * 60` for 30-day), simulating "recent signal density" the
  way a real rolling-window aggregation would look, without an actual
  historical event log to aggregate.
- `signal_density_ratio` — `signal_count_7d / (signal_count_30d + 1)`, a
  recency-weighting ratio: a zone with most of its 30-day signals
  concentrated in the last week reads as an emerging hotspot, distinct
  from one with the same 30-day total spread evenly.

In a real deployment, both would be computed directly from
`rakshak-sos-alerts` (an actual rolling aggregation is already
straightforward given `created_at` + the new `status-created_at-index` —
see `DATABASE_SCHEMA.md`) instead of simulated.

## Demographic

- `victim_age` — sampled from four age bands (15–25, 25–45, 45–65, 65–85)
  weighted 30/40/20/10%. Present in the training feature set; the live
  inference resolver (`_vector_for` in `rakshak_common.py`) defaults it
  when not supplied by the caller (`FEATURE_DEFAULTS["victim_age"] = 27.0`)
  since a zone-level prediction has no specific victim.

## Label construction

```
risk_score = base_risk
  + 0.12 if is_night
  + 0.08 if signal_count_last_7d > 12
  + 0.05 if response_time_minutes > 15
  + 0.05 if reporting_delay_minutes > 20

risk_level = High   if risk_score >= 0.65
             Medium if risk_score >= 0.40
             Low    otherwise
```

This is an explicit, auditable rule — anyone can recompute `risk_level`
from the other columns and verify it matches. That auditability was a
deliberate choice: an opaque or ML-generated label would make the
downstream classifier's "accuracy" numbers meaningless in a different way
than they already are for a rule-derived label (see `ML_PIPELINE.md`
evaluation section for the honest reading of those numbers).
