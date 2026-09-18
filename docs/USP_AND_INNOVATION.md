# USP and Innovation

A factual, feature-by-feature comparison against what a typical SOS/safety
app does, with no marketing language — every claim below is checkable
against this repository's code or the live API.

## Predictive safety scoring

**Typical**: a static or crowd-reported "unsafe area" flag, if present at
all. **Rakshak**: every one of the 44 serviced zones has a live risk score
(`GET /prediction/{zone}`, `GET /dashboard/heatmap`) from a trained
XGBoost model, served in ~130ms warm. The score updates with time-of-day
(night/rush-hour features are part of the model input, not a static
lookup) — the same zone reads differently at 2pm and 2am because the
model actually takes `hour`/`is_night` as inputs, not because of a
hand-coded time-of-day multiplier applied after the fact.

Honest caveat, stated plainly rather than hidden: the model is trained on
a synthetic, formula-labeled dataset (`DATASET_CARD.md`) — the *mechanism*
(real-time, feature-driven, per-zone scoring) is real and live; the
*calibration* against real-world outcomes is not yet validated, because no
real incident data was available within this project's scope.

## Intelligent patrol allocation

**Typical**: no patrol awareness at all — an SOS app that doesn't know
where responders are. **Rakshak**: `POST /sos` auto-assigns the nearest
*currently available* patrol unit in the same call that creates the
incident, using each unit's **live computed position** (not its nominal
home base) and a conditional DynamoDB write that makes double-assignment
structurally impossible under concurrent requests (`PATROL_SIMULATION.md`).
If every unit is busy, the incident is explicitly marked "Awaiting Patrol"
rather than silently failing or assigning nothing.

## ETA engine

**Typical**: none, or a static "police notified" message with no timing
information. **Rakshak**: `eta_seconds` is recomputed on every read from
the responding unit's actual live position and speed
(`lerp_toward` — `PATROL_SIMULATION.md`), so it counts down accurately
even if the assigned unit was itself mid-route when the SOS was raised,
and even under irregular client poll timing.

## Unified emergency ecosystem

**Typical**: a single citizen-facing app, if the responder side exists at
all it's a separate, disconnected system. **Rakshak**: three apps —
citizen, police, command dashboard — share one API contract and one data
model. An incident created by the citizen app is immediately visible in
the police app's live feed and the dashboard's timeline, with no
integration layer or sync job between them — they're reading the same
DynamoDB tables through the same Lambda functions.

## Central command analytics

**Typical**: none, or a simple incident list. **Rakshak**: a dedicated
dashboard service (`rakshak-dashboard`) serving city-wide snapshot
(counts by status), timeline (recent events across all incidents), and
the full 44-zone risk heatmap — all three read the same underlying tables
the operational apps write to, so there's no separate analytics pipeline
or data warehouse to keep in sync.

## ML-driven hotspot prediction

**Typical**: none, or a static heatmap built once from historical
reports. **Rakshak**: `signal_count_last_7d`/`_30d` and
`signal_density_ratio` are model features specifically designed to
surface emerging hotspots — a zone with signals concentrated in the last
week reads differently from one with the same 30-day total spread evenly
(`FEATURE_ENGINEERING.md`). In production, these would compute directly
from live incident data via the new `status-created_at-index` GSI
(`DATABASE_SCHEMA.md`) rather than the current synthetic defaults.

## Engineering choices that back these claims up

Not user-facing features, but the reasons the above are actually reliable
rather than demo-only tricks:

- **Batched inference**: the 44-zone heatmap is one model call, not 44
  (`ML_PIPELINE.md`) — a from-scratch competitor doing per-zone API calls
  would be an order of magnitude slower at the same zone count.
- **3-tier ML resolver with a circuit breaker**: `/predict` has never
  returned a `500` due to a downstream ML failure since this was added —
  it degrades to a baseline score instead (`ML_PIPELINE.md`).
- **Compute-on-read patrol positions**: no scheduler, no missed-tick
  drift, no idle compute cost for 20 units running "continuously"
  (`PATROL_SIMULATION.md`).
- **Idempotent infrastructure**: the entire AWS deployment can be re-run
  with zero unintended side effects — verified this pass with a
  double dry-run showing zero mutating actions on the second pass
  (`DEPLOYMENT.md`).
