# Database Schema

DynamoDB, `PAY_PER_REQUEST` billing on every table. No joins, no
multi-table transactions — every access pattern is a point lookup by key or
a scan/query filtered in application code (see the GSI note below for the
one pattern that outgrew a scan).

## `rakshak-sos-alerts`

The core incident table. Despite the name, this holds every citizen SOS —
"alerts" here means the live/historical SOS feed, not a notification log.

| Attribute | Type | Notes |
|---|---|---|
| `sos_id` (PK) | S | `SOS-` + 8 hex chars |
| `status` | S | `active` → `dispatched` → `reached` → `resolved` \| `cancelled` |
| `created_at`, `updated_at`, `triggered_at` | S (ISO 8601) | |
| `user_id`, `username` | S | |
| `pincode`, `zone_name` | S | resolved from lat/lng via `zone_for_point()` if not supplied |
| `risk_level` | S | citizen-reported severity at creation |
| `lat`/`lng` **and** `latitude`/`longitude` | N (Decimal) | both key spellings stored — the citizen app and dashboard historically used different ones |
| `assigned_patrol_id`, `assigned_officer`, `assigned_vehicle` | S | set by auto-dispatch or manual dispatch |
| `eta_seconds` | N | live only while `dispatched`; `0` once `reached`/`resolved` |
| `events` | List\<Map\> | full timeline — `{type, message, timestamp, patrol_id?}`, append-only via `append_events()` |
| `dispatched_at`, `reached_at`, `resolved_at`, `cancelled_at`, `accepted_at`, `accepted_by` | S | set on the matching transition only |

**GSI: `status-created_at-index`** — PK `status`, SK `created_at`. Added
this pass to replace a full-table scan on every `GET /incidents/active` /
`GET /police/sos/active` call. The application code still does an in-Lambda
filter for `LIVE_STATES = (active, dispatched, reached)` rather than 3
separate `Query` calls (one per status) — a possible follow-up, not applied
here because the current scan-then-filter is well under the verified
performance budget (139ms warm p50 on `/incidents/active`'s sibling routes)
and 9 items in the live table make the difference immaterial today; revisit
if incident volume grows.

## `rakshak-patrols`

20 units, `PATROL_UNITS` in `rakshak_common.py` defines the static roster
(name, officer, vehicle, home pincode, route). The DynamoDB row holds only
*mutable* state — position is **never stored**, always derived on read.

| Attribute | Type | Notes |
|---|---|---|
| `patrol_id` (PK) | S | `P001`–`P020` |
| `status` | S | `Patrolling` \| `Responding` \| `AtScene` \| `Returning` |
| `cycle_start_ts` | N (epoch) | anchor for computing position while `Patrolling` — see `PATROL_SIMULATION.md` |
| `assigned_sos_id` | S | set only while `Responding`/`AtScene` |
| `sos_lat`, `sos_lng` | N | target coordinates while responding |
| `divert_start_ts`, `divert_from_lat`, `divert_from_lng` | N | anchor for the diversion lerp |
| `return_start_ts`, `return_from_lat`, `return_from_lng` | N | anchor for the return-to-route lerp |
| `updated_at` | S (ISO 8601) | |

No GSI — every read is either a `get_item` by `patrol_id` or a full
20-row scan (`GET /patrols`), which is cheaper than a GSI would be to
maintain at this table size.

## `rakshak-incidents`

Citizen-submitted safety reports (moderation queue) — **not** SOS
incidents, despite the similar name. This naming collision with
`rakshak-sos-alerts` is a known trap, documented here and in
`ARCHITECTURE_AUDIT.md`, not renamed in this pass (a table rename is a
breaking, high-blast-radius change with no functional benefit — the code
is correct, just the names invite confusion).

| Attribute | Type | Notes |
|---|---|---|
| `incident_id` (PK) | S | |
| `created_at` (SK) | S (ISO 8601) | |
| `status` | S | `pending` → `approved` \| `rejected` |
| body fields | — | submitted by `POST /reports/submit`, moderated via `PATCH /reports/approve/{id}` / `PATCH /reports/reject/{id}` |

## `rakshak-users`

Citizen night-mode ping heartbeats (`rakshak-night-monitor`), not an auth
user table — there is no login/session system in this backend (see
`SECURITY_MODEL.md`).

| Attribute | Type | Notes |
|---|---|---|
| `user_id` (PK) | S | |
| ping fields | — | last-seen location/timestamp, written by `POST /citizens/ping` |

## `rakshak-zones`

Defined and provisioned, **0 items** — not currently written to or read
from by any managed Lambda. Zone metadata (name, geometry, base risk) is
served instead from `assets/chennai_zones.geojson` (64 polygons, vendored
into the Lambda zips) and the hand-authored pincode dict in
`rakshak_common.py`. Kept provisioned rather than deleted since removing a
table is a one-way action with no current benefit; a genuine
follow-up would be to either populate it as the zone-metadata source of
truth or drop it.

## Legacy, unmanaged tables

`patrol_vehicles`, `sos_alerts`, `user_locations` — pre-date this backend,
not written to by any current Lambda, not touched by `deploy.py`. Kept for
reference; see `AWS_RESOURCES.md` for item counts.
