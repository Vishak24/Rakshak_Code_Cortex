# API Reference

Base URL: `https://aksdwfbnn5.execute-api.ap-south-1.amazonaws.com`
No authentication — every route is public (see `SECURITY_MODEL.md` for why,
and the gap that implies). All responses are JSON; all timestamps ISO 8601.
Native CORS is enabled API-wide (`*` origin, `GET,POST,PATCH,OPTIONS`).

Sample request/response payloads for every route below live in
[`api-samples/`](api-samples/) — captured from the live API, not
hand-written.

## Frozen contract (14 routes)

The routes this build's architecture targets. Every one of these is also
reachable through a legacy alias below where one existed before this pass;
the contract paths are the ones new integration work should use.

### Citizen

| Method | Path | Function | Notes |
|---|---|---|---|
| `POST` | `/sos` | `rakshak-sos-handler` | Create an incident. Auto-assigns the nearest free patrol in the same call. Body: `{user_id, username, latitude, longitude, pincode?, risk_level?}`. Returns `201` with `{sos_id, status, assigned_patrol_id, eta_seconds, ...}`. |
| `GET` | `/incident/{id}` | `rakshak-sos-handler` | Single incident, enriched with live patrol position/ETA. |
| `GET` | `/incident/{id}/eta` | `rakshak-sos-handler` | ETA + live patrol position only — for a tight poll interval. |

### Police

| Method | Path | Function | Notes |
|---|---|---|---|
| `GET` | `/incidents/active` | `rakshak-sos-handler` | Live feed (`active`/`dispatched`/`reached`), sorted by distance to `?officer_lat=&officer_lng=`. `?patrol_id=` filters to one unit's incident. |
| `PATCH` | `/incident/{id}/accept` | `rakshak-sos-handler` | Records acknowledgment (`accepted_by`, `accepted_at`) without changing status — the backend already auto-dispatches, so there's no separate accept/reject decision. |
| `PATCH` | `/incident/{id}/status` | `rakshak-sos-handler` | Body `{status, officer_id?, notes?}`. `status` accepts any alias in the table below. |
| `PATCH` | `/incident/{id}/resolve` | `rakshak-sos-handler` | Shorthand for `PATCH .../status` with `status=resolved`. |

### Dashboard

| Method | Path | Function | Notes |
|---|---|---|---|
| `GET` | `/dashboard/snapshot` | `rakshak-dashboard` | City-wide counts: patrols by status, incidents by status. |
| `GET` | `/dashboard/patrols` | `rakshak-patrol-handler` | All 20 units with live positions. |
| `GET` | `/dashboard/timeline` | `rakshak-dashboard` | Recent incident events, newest first. |
| `GET` | `/dashboard/heatmap` | `rakshak-dashboard` | All 44 serviced zones with live ML safety scores. |

### Prediction

| Method | Path | Function | Notes |
|---|---|---|---|
| `GET` | `/prediction/{zone}` | `rakshak-dashboard` | Single-zone risk score. `{zone}` is a pincode. |
| `POST` | `/predict` | `rakshak-test-inference` | Body: `{pincode, ...feature overrides}`. Returns `{safetyScore, riskLevel, confidence, source}`. |

### System

| Method | Path | Function | Notes |
|---|---|---|---|
| `GET` | `/health` | `rakshak-dashboard` | Liveness check. |
| `GET` | `/version` | `rakshak-dashboard` | `{version, generated_at}` — `version` from `BUILD_VERSION` env or the code default. |

## Status aliases (`PATCH .../status`)

| Accepted values | Canonical |
|---|---|
| `dispatched`, `assign`, `en_route` | `dispatched` |
| `reached`, `at_scene`, `atscene`, `arrived` | `reached` |
| `resolved`, `resolve`, `closed`, `done` | `resolved` |
| `cancelled`, `canceled`, `cancel` | `cancelled` |

Anything else returns `400`. Once an incident reaches a terminal state
(`resolved`/`cancelled`) it cannot move back to a live state — `400`.

## Legacy / compatibility routes (23 routes)

Kept live, unchanged, so the current app builds keep working without a
redeploy. New work should prefer the contract paths above.

| Method | Path | Function |
|---|---|---|
| `POST` | `/sos/live` | `rakshak-sos-handler` |
| `GET` | `/sos/live` | `rakshak-sos-handler` |
| `POST` | `/sos/dispatch/{id}` | `rakshak-sos-handler` |
| `PATCH` | `/sos/resolve/{id}` | `rakshak-sos-handler` |
| `POST` | `/sos/cancelled` | `rakshak-sos-handler` |
| `GET` | `/police/sos/active` | `rakshak-sos-handler` |
| `PATCH` | `/police/sos/{sos_id}/status` | `rakshak-sos-handler` |
| `GET` | `/patrols` | `rakshak-patrol-handler` |
| `PATCH` | `/patrols/{id}/status` | `rakshak-patrol-handler` |
| `POST` | `/patrol/optimize` | `rakshak-patrol-handler` |
| `GET` | `/heatmap/live` | `rakshak-dashboard` |
| `GET` | `/prediction/zone/{zoneId}` | `rakshak-dashboard` |
| `GET` | `/reports` | `rakshak-reports-handler` |
| `POST` | `/reports/submit` | `rakshak-reports-handler` |
| `PATCH` | `/reports/approve/{id}` | `rakshak-reports-handler` |
| `PATCH` | `/reports/reject/{id}` | `rakshak-reports-handler` |
| `GET` | `/police/citizens/active` | `rakshak-night-monitor` |
| `POST` | `/citizens/ping` | `rakshak-night-monitor` |
| `GET` | `/police/route` | `rakshak-routing` |
| `POST` | `/scan` | `rakshak-scan-inference` (orphaned — see `lambdas/_legacy/README.md`) |

`/incident/{id}/accept`, `/incident/{id}/status`, `/incident/{id}/resolve`,
and `/incidents/active` were previously served by the now-retired
`rakshak-sos-feed` function; they're listed once, above, under the frozen
contract, since that's the current source of truth.

## Errors

| Code | Meaning |
|---|---|
| `400` | Bad request — missing/invalid field, out-of-range coordinate, invalid status transition |
| `404` | Not found — unknown `sos_id`/`patrol_id`/`incident_id`, or a pincode outside the 44 serviced zones on `/predict` |
| `500` | Unhandled error — every handler wraps its router in `try/except` and returns a structured 500 rather than a raw Lambda crash |

Sample error bodies: `api-samples/error__400.json`, `api-samples/error__404.json`.
