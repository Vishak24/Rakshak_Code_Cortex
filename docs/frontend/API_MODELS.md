# API Models — Flutter + TypeScript

Every model below is derived from real captured live payloads
(`docs/api-samples/*.json`, all captured from the live API, and re-verified
live 2026-09-18 during this audit) and cross-checked against the Lambda
source that produces them (`backend/lambdas/*/lambda_function.py`,
`backend/lambdas/_shared/rakshak_common.py`). Flutter and TypeScript
definitions are kept field-identical; where the backend itself is
inconsistent (documented below), both language models carry the same
inconsistency rather than silently normalizing it, so a bug in one platform
is reproducible in the other.

**Nullability rule used throughout:** a field is nullable if any real
captured sample or read source path shows it as `null`/absent for a valid
row (e.g. a `Patrolling` unit's `assigned_sos_id` is `null`; that's normal,
not missing data).

## IncidentModel

Backs `POST /sos`, `GET /incident/{id}`, `GET /incidents/active`,
`GET /sos/live`, `GET /police/sos/active`. Source: `rakshak-sos-handler`.

| Field | Type | Nullable | Example | Notes |
|---|---|---|---|---|
| `sos_id` | string | no | `"SOS-7594E58D"` | PK, `SOS-` + 8 hex chars |
| `status` | string | no | `"dispatched"` | `active`\|`dispatched`\|`reached`\|`resolved`\|`cancelled` |
| `created_at`, `triggered_at`, `updated_at` | string (ISO 8601, UTC, `Z`) | no | `"2026-09-04T05:43:28.616132Z"` | |
| `user_id` | string | no | `"citizen-421"` | self-reported, unauthenticated |
| `username` | string | no | `"Asha"` | self-reported |
| `pincode` | string | yes | `"600020"` | resolved server-side from lat/lng if omitted |
| `zone_name` | string | yes | `"Adyar"` | **can be the raw pincode string** (e.g. `"600023"`) if the pincode isn't in the 44-zone name table — fall back to a local map, don't assume it's human-readable |
| `risk_level` | string | no | `"HIGH"` | citizen-reported severity at creation, uppercase |
| `lat`, `lng` | number | yes | `13.0067` | present together or both absent |
| `latitude`, `longitude` | number | yes | `13.0067` | **duplicate of `lat`/`lng`**, same value, intentional dual-spelling — prefer these two in new code |
| `battery` | number | yes | `47` | caller-supplied, frequently `null` |
| `network` | string | yes | `"4G"` | caller-supplied, frequently `null` |
| `assigned_patrol_id` | string | yes | `"P012"` | `null` while queued/awaiting |
| `assigned_officer` | string | yes | `"SI Deepa N"` | |
| `assigned_vehicle` | string | yes | `"TN01-PCR-12"` | |
| `eta_seconds` | integer | yes | `184` | `0` once `reached`/`resolved`; `null` while awaiting a patrol |
| `distance_km` | number | yes | `6.09` | **only present on `GET /incidents/active` rows** (distance to the requesting officer) |
| `distance_m` | integer | yes | `2804` | **only present when the assigned patrol's status is `Responding`** (en route) — absent otherwise |
| `area_name` | string | yes | `"Adyar"` | **only present on `GET /incidents/active`**, duplicate of `zone_name` |
| `patrol_position` | `{lat: number, lng: number}` | yes | `{"lat":13.03,"lng":80.24}` | live-computed, present only while `dispatched`/`reached` |
| `patrol_status` | string | yes | `"Responding"` | **only on `GET /incidents/active`** |
| `officer_id` | string | yes | `"OFF-7"` | set on `reached`/`resolved` transition if provided |
| `dispatched_at`, `reached_at`, `resolved_at`, `cancelled_at`, `accepted_at` | string (ISO 8601) | yes | | set only on the matching transition |
| `accepted_by` | string | yes | | set by `PATCH /incident/{id}/accept` |
| `notes` | string | yes | | officer-entered, ≤500 chars, set on `reached`/`resolved`/`cancelled` |
| `events` | `TimelineEventModel[]` | no (may be empty `[]`) | | append-only |

### Flutter — `IncidentModel`

```dart
class IncidentModel {
  final String sosId;
  final String status; // active | dispatched | reached | resolved | cancelled
  final DateTime createdAt;
  final DateTime triggeredAt;
  final DateTime updatedAt;
  final String userId;
  final String username;
  final String? pincode;
  final String? zoneName; // may be a raw pincode string — see notes
  final String riskLevel;
  final double? latitude;   // prefer over lat/lng
  final double? longitude;
  final int? battery;
  final String? network;
  final String? assignedPatrolId;
  final String? assignedOfficer;
  final String? assignedVehicle;
  final int? etaSeconds;
  final double? distanceKm;   // GET /incidents/active only
  final int? distanceM;       // only while patrol status == Responding
  final String? areaName;     // GET /incidents/active only
  final LatLng? patrolPosition;
  final String? patrolStatus; // GET /incidents/active only
  final String? officerId;
  final DateTime? dispatchedAt;
  final DateTime? reachedAt;
  final DateTime? resolvedAt;
  final DateTime? cancelledAt;
  final DateTime? acceptedAt;
  final String? acceptedBy;
  final String? notes;
  final List<TimelineEventModel> events;
}
```

### TypeScript — `IncidentModel`

```typescript
interface IncidentModel {
  sos_id: string;
  status: "active" | "dispatched" | "reached" | "resolved" | "cancelled";
  created_at: string;   // ISO 8601 UTC
  triggered_at: string;
  updated_at: string;
  user_id: string;
  username: string;
  pincode?: string;
  zone_name?: string;      // may be a raw pincode string — see notes
  risk_level: string;
  latitude?: number;       // prefer over lat/lng
  longitude?: number;
  lat?: number;
  lng?: number;
  battery?: number | null;
  network?: string | null;
  assigned_patrol_id?: string | null;
  assigned_officer?: string;
  assigned_vehicle?: string;
  eta_seconds?: number | null;
  distance_km?: number;    // GET /incidents/active only
  distance_m?: number;     // only while patrol status == Responding
  area_name?: string;      // GET /incidents/active only
  patrol_position?: { lat: number; lng: number } | null;
  patrol_status?: string;  // GET /incidents/active only
  officer_id?: string;
  dispatched_at?: string;
  reached_at?: string;
  resolved_at?: string;
  cancelled_at?: string;
  accepted_at?: string;
  accepted_by?: string;
  notes?: string;
  events: TimelineEventModel[];
}
```

## PatrolModel

Backs `GET /patrols`, `GET /dashboard/patrols`. Source: `rakshak-patrol-handler`
via `rakshak_common.compute_patrol_view()` — **position is never stored, it's
derived on every read** from route waypoints + elapsed time.

| Field | Type | Nullable | Example | Notes |
|---|---|---|---|---|
| `patrol_id` | string | no | `"P012"` | `P001`–`P020` |
| `name` | string | no | `"Unit Lima"` | |
| `officer` | string | no | `"SI Deepa N"` | |
| `vehicle` | string | no | `"TN01-PCR-12"` | |
| `zone` | string | no | `"600085"` | pincode string |
| `zone_name` | string | no | `"600085"` | **can be the raw pincode**, same caveat as Incident |
| `status` | string | no | `"Responding"` | `Patrolling`\|`Responding`\|`AtScene`\|`Returning` — capitalized, distinct vocabulary from incident `status` |
| `position` | `{lat: number, lng: number}` | yes | `{"lat":13.02,"lng":80.24}` | always present in practice; typed nullable because the source can return `null` if waypoints are empty |
| `eta_seconds` | integer | yes | `184` | `null` while `Patrolling`/`Returning`; `0` while `AtScene` |
| `distance_m` | integer | yes | `2804` | **only while `Responding`** |
| `assigned_sos_id` | string | yes | `"SOS-7594E58D"` | `null` unless `Responding`/`AtScene` |
| `heading` | string | no | `"to_scene"` | `patrol`\|`to_scene`\|`on_scene`\|`returning` — a UI hint, not a compass bearing |
| `updated_at` | string (ISO 8601) | no | | |

### Flutter — `PatrolModel`

```dart
class PatrolModel {
  final String patrolId;
  final String name;
  final String officer;
  final String vehicle;
  final String zone;
  final String zoneName; // may be a raw pincode string
  final String status; // Patrolling | Responding | AtScene | Returning
  final LatLng? position;
  final int? etaSeconds;
  final int? distanceM;       // only while status == Responding
  final String? assignedSosId;
  final String heading; // patrol | to_scene | on_scene | returning
  final DateTime updatedAt;
}
```

### TypeScript — `PatrolModel`

```typescript
interface PatrolModel {
  patrol_id: string;
  name: string;
  officer: string;
  vehicle: string;
  zone: string;
  zone_name: string;   // may be a raw pincode string
  status: "Patrolling" | "Responding" | "AtScene" | "Returning";
  position: { lat: number; lng: number } | null;
  eta_seconds: number | null;
  distance_m?: number;  // only while status === "Responding"
  assigned_sos_id: string | null;
  heading: "patrol" | "to_scene" | "on_scene" | "returning";
  updated_at: string;
}
```

## PredictionModel

Backs `GET /prediction/{zone}`, `POST /predict`, `GET /prediction/zone/{zoneId}`.
Source: `rakshak_common.predict_safety()` / `predict_batch()`.

**Naming split, confirmed at source level, permanent — see
`FRONTEND_INTEGRATION_GUIDE.md` mismatch #3:** this model is **camelCase**.
The per-zone entries inside `DashboardSnapshotModel.high_risk_zones` and
`HeatmapModel.zones` are a *different, snake_case* shape
(`safety_score`/`risk_level`) even though they represent the same score —
see the note under `HeatmapZoneModel` below. Do not merge these two shapes
into one client-side type without keeping both key spellings; a "fix" that
picks one spelling will silently break whichever route uses the other.

| Field | Type | Nullable | Example | Notes |
|---|---|---|---|---|
| `safetyScore` | integer 0–100 | no | `58` | higher = safer; floor is 10 (never reads as "0 = no data") |
| `riskLevel` | string | no | `"MEDIUM"` | `LOW`\|`MEDIUM`\|`HIGH`, derived from `safetyScore`, never contradicts it |
| `confidence` | number 0–1 | no | `0.55` | `0.55` specifically means the `baseline` tier answered (fixed constant, not a real model confidence) |
| `zone` | string | no | `"Adyar"` | human zone name |
| `pincode` | string | no | `"600020"` | |
| `source` | string | no | `"baseline"` | `sagemaker`\|`s3-model`\|`baseline` — which tier answered; SageMaker endpoint does not currently exist, so expect `s3-model` or `baseline` in practice |

### Flutter — `PredictionModel`

```dart
class PredictionModel {
  final int safetyScore;   // 0-100, higher = safer
  final String riskLevel;  // LOW | MEDIUM | HIGH
  final double confidence; // 0-1; 0.55 means the baseline tier answered
  final String zone;
  final String pincode;
  final String source; // sagemaker | s3-model | baseline
}
```

### TypeScript — `PredictionModel`

```typescript
interface PredictionModel {
  safetyScore: number;  // 0-100, higher = safer
  riskLevel: "LOW" | "MEDIUM" | "HIGH";
  confidence: number;   // 0-1; 0.55 means the baseline tier answered
  zone: string;
  pincode: string;
  source: "sagemaker" | "s3-model" | "baseline";
}
```

## DashboardSnapshotModel

Backs `GET /dashboard/snapshot`. Source: `rakshak-dashboard/_snapshot()`.

| Field | Type | Notes |
|---|---|---|
| `generated_at` | string (ISO 8601) | |
| `patrols.total` / `.on_patrol` / `.responding` / `.at_scene` / `.returning` | integer | counts across all 20 units |
| `officers_available` | integer | == `patrols.on_patrol` (only `Patrolling` units count as "available") |
| `officers_on_duty` | integer | == `patrols.total` |
| `incidents.active_total` | integer | count of `active`+`dispatched`+`reached` |
| `incidents.awaiting` / `.dispatched` / `.on_scene` | integer | breakdown of `active_total` by exact status (`awaiting`=`active`, `on_scene`=`reached`) |
| `resolved_today`, `cancelled_today` | integer | scoped to the current IST calendar day |
| `high_risk_zones` | `HeatmapZoneModel[]` (snake_case, see below) | **top 5 by `safety_score` ascending only** — not the full 44-zone set |
| `active_incident_ids` | `string[]` | `sos_id` values, for direct-lookup follow-up calls |

### Flutter — `DashboardSnapshotModel`

```dart
class PatrolCounts {
  final int total, onPatrol, responding, atScene, returning;
}
class IncidentCounts {
  final int activeTotal, awaiting, dispatched, onScene;
}
class DashboardSnapshotModel {
  final DateTime generatedAt;
  final PatrolCounts patrols;
  final int officersAvailable;
  final int officersOnDuty;
  final IncidentCounts incidents;
  final int resolvedToday;
  final int cancelledToday;
  final List<HeatmapZoneModel> highRiskZones; // top 5 only
  final List<String> activeIncidentIds;
}
```

### TypeScript — `DashboardSnapshotModel`

```typescript
interface DashboardSnapshotModel {
  generated_at: string;
  patrols: { total: number; on_patrol: number; responding: number; at_scene: number; returning: number };
  officers_available: number;
  officers_on_duty: number;
  incidents: { active_total: number; awaiting: number; dispatched: number; on_scene: number };
  resolved_today: number;
  cancelled_today: number;
  high_risk_zones: HeatmapZoneModel[]; // top 5 only
  active_incident_ids: string[];
}
```

## HeatmapZoneModel (snake_case — the OTHER prediction shape)

Backs `GET /dashboard/heatmap`, `GET /heatmap/live`, and
`DashboardSnapshotModel.high_risk_zones`. Source: `_zone_scores()`, which
takes `predict_batch()`'s camelCase output and re-maps it, additionally
subtracting an incident-density penalty (`-6` per incident today, `-10` per
currently-active incident in that zone, floored at 10).

| Field | Type | Example | Notes |
|---|---|---|---|
| `pincode` | string | `"600011"` | |
| `zone_name` | string | `"Perambur"` | |
| `lat`, `lng` | number | `13.11, 80.24` | zone centroid, for the heatmap layer |
| `safety_score` | integer 0–100 | `14` | **snake_case** — same scale as `PredictionModel.safetyScore` but a distinct field name and a distinct (density-adjusted) value; do not assume the two are numerically identical for the same pincode at the same instant |
| `risk_level` | string | `"HIGH"` | **snake_case** |
| `incidents_today` | integer | `1` | IST calendar day |
| `active_incidents` | integer | `0` | currently `active`/`dispatched`/`reached` in this zone |
| `source` | string | `"baseline"` | same 3-tier vocabulary as `PredictionModel.source` |

`GET /dashboard/heatmap` wraps the array as `{generated_at, zone_count,
zones: HeatmapZoneModel[]}` (44 zones in practice).

### Flutter / TypeScript

```dart
class HeatmapZoneModel {
  final String pincode, zoneName;
  final double lat, lng;
  final int safetyScore; // snake_case field, camelCase Dart property by convention
  final String riskLevel;
  final int incidentsToday, activeIncidents;
  final String source;
}
```

```typescript
interface HeatmapZoneModel {
  pincode: string;
  zone_name: string;
  lat: number;
  lng: number;
  safety_score: number;
  risk_level: string;
  incidents_today: number;
  active_incidents: number;
  source: "sagemaker" | "s3-model" | "baseline";
}
```

## TimelineEventModel

Backs `GET /dashboard/timeline`, and the `events[]` array embedded in
`IncidentModel`. Source: `rakshak_common.make_event()` /
`rakshak-dashboard/_timeline()`.

**Correction to `DATABASE_SCHEMA.md`:** that doc describes this shape as
`{type, message, timestamp, patrol_id}`. The live shape (confirmed via
`docs/api-samples/GET_dashboard_timeline.json` and the `make_event()`
source) is below — use `ts`/`detail`, not `timestamp`/`message`.

| Field | Type | Nullable | Example | Notes |
|---|---|---|---|---|
| `sos_id` | string | no (embedded in timeline; absent when nested inside `IncidentModel.events`) | `"SOS-3497369C"` | only on the flattened `GET /dashboard/timeline` response |
| `pincode`, `zone_name` | string | yes | `"600011"`, `"Perambur"` | only on `GET /dashboard/timeline` |
| `type` | string | no | `"Patrol Assigned"` | one of: `SOS Created`, `Patrol Assigned`, `En Route`, `Reached`, `Resolved`, `Cancelled`, `Awaiting Patrol`, `Accepted` — human-readable, not a machine enum key |
| `ts` | string (ISO 8601) | no | `"2026-09-04T05:43:28.616909Z"` | |
| `detail` | string | no (may be `""`) | `"Unit Hotel (TN01-PCR-08) assigned"` | human-readable, safe to render directly |
| `patrol_id` | string | yes | `"P008"` | `null` on the initial `SOS Created` event |

### Flutter — `TimelineEventModel`

```dart
class TimelineEventModel {
  final String? sosId;      // only on GET /dashboard/timeline
  final String? pincode;    // only on GET /dashboard/timeline
  final String? zoneName;   // only on GET /dashboard/timeline
  final String type;
  final DateTime ts;
  final String detail;
  final String? patrolId;
}
```

### TypeScript — `TimelineEventModel`

```typescript
interface TimelineEventModel {
  sos_id?: string;
  pincode?: string;
  zone_name?: string;
  type: "SOS Created" | "Patrol Assigned" | "En Route" | "Reached" | "Resolved" | "Cancelled" | "Awaiting Patrol" | "Accepted";
  ts: string;
  detail: string;
  patrol_id?: string | null;
}
```

## HealthResponseModel

Backs `GET /health`. Captured live 2026-09-18.

| Field | Type | Example |
|---|---|---|
| `status` | string | `"ok"` (or `"degraded"` if a DynamoDB check or the ML probe fails — check this field, not just HTTP 200) |
| `checks` | `Record<string, string>` | `{"dynamodb:rakshak-patrols":"ok","dynamodb:rakshak-sos-alerts":"ok","ml":"s3-model"}` |
| `ml_tiers` | `{sagemaker: string, "s3-model": string}` | `{"sagemaker":"cooldown (299s left)","s3-model":"open"}` — circuit-breaker state, human-readable strings not enums |
| `version` | string | `"1.0.0"` |
| `generated_at` | string (ISO 8601) | |

### Flutter / TypeScript

```dart
class HealthResponseModel {
  final String status; // ok | degraded
  final Map<String, String> checks;
  final Map<String, String> mlTiers;
  final String version;
  final DateTime generatedAt;
}
```

```typescript
interface HealthResponseModel {
  status: "ok" | "degraded";
  checks: Record<string, string>;
  ml_tiers: { sagemaker: string; "s3-model": string };
  version: string;
  generated_at: string;
}
```

## VersionResponseModel

Backs `GET /version`. Captured live 2026-09-18: `{"version": "1.0.0",
"generated_at": "2026-09-18T09:14:41.033597Z"}`.

```dart
class VersionResponseModel {
  final String version;
  final DateTime generatedAt;
}
```

```typescript
interface VersionResponseModel {
  version: string;
  generated_at: string;
}
```
