# API Endpoint Reference

Full route table, generated from live account `468704514492` (`ap-south-1`)
+ `deploy/routes.py` + `backend/lambdas/*/lambda_function.py` source, audited
2026-09-18. This is the human-readable companion to
[`../../shared/api/API_CONTRACT.json`](../../shared/api/API_CONTRACT.json)
(machine-readable, same data). Real request/response bodies for most routes
are in [`../api-samples/`](../api-samples/) — this table links to them
rather than duplicating them, except where this audit captured a *new* live
sample that didn't exist before.

Base URL: `https://aksdwfbnn5.execute-api.ap-south-1.amazonaws.com` — no
stage path, no auth on any route.

## Frozen contract (15 routes — see reconciliation note below)

| Method | Path | Function | Team | Status codes | Sample |
|---|---|---|---|---|---|
| `POST` | `/sos` | `rakshak-sos-handler` | Citizen | 201, 400 | `POST_sos_live__response.json` (identical handler) |
| `GET` | `/incident/{id}` | `rakshak-sos-handler` | Citizen | 200, 400, 404 | *captured this audit* — see below |
| `GET` | `/incident/{id}/eta` | `rakshak-sos-handler` | Citizen | 200, 400, 404 | *captured this audit* — see below |
| `GET` | `/incidents/active` | `rakshak-sos-handler` | Police | 200 | `GET_police_sos_active.json` (identical handler) |
| `PATCH` | `/incident/{id}/accept` | `rakshak-sos-handler` | Police | 200, 400, 404 | not captured — see `API_MODELS.md`/source-derived shape |
| `PATCH` | `/incident/{id}/status` | `rakshak-sos-handler` | Police | 200, 400, 404 | `PATCH_police_sos_status__reached.json` (identical handler) |
| `PATCH` | `/incident/{id}/resolve` | `rakshak-sos-handler` | Police | 200, 400, 404 | `PATCH_sos_resolve.json` (identical handler) |
| `GET` | `/dashboard/snapshot` | `rakshak-dashboard` | Dashboard | 200 | `GET_dashboard_snapshot.json` |
| `GET` | `/dashboard/patrols` | `rakshak-patrol-handler` | Dashboard | 200 | `GET_patrols.json` (byte-identical live, verified this audit) |
| `GET` | `/dashboard/timeline` | `rakshak-dashboard` | Dashboard | 200 | `GET_dashboard_timeline.json` |
| `GET` | `/dashboard/heatmap` | `rakshak-dashboard` | Dashboard | 200 | `GET_heatmap_live.json` (byte-identical live, verified this audit) |
| `GET` | `/prediction/{zone}` | `rakshak-dashboard` | Prediction | 200, 404 | `GET_prediction_zone.json` |
| `POST` | `/predict` | `rakshak-test-inference` | Prediction | 200, 400, 404 | `POST_predict.json` |
| `GET` | `/health` | `rakshak-dashboard` | System | 200 | *captured this audit* — see below |
| `GET` | `/version` | `rakshak-dashboard` | System | 200 | *captured this audit* — see below |

**Reconciliation note:** `deploy/routes.py`'s `CONTRACT` list has **15**
entries (`API_REFERENCE.md`'s prose says 14 — an off-by-one in that doc,
not corrected here per this audit's read-only scope). Total live routes are
37 = 15 contract + 20 legacy + `OPTIONS /{proxy+}` (gateway-internal CORS
catch-all) + `POST /score/refresh` (undocumented orphaned route — see
Integration Mismatches below).

### Newly captured live samples (this audit, 2026-09-18)

```
GET /health
{"status": "ok", "checks": {"dynamodb:rakshak-patrols": "ok", "dynamodb:rakshak-sos-alerts": "ok", "ml": "s3-model"}, "ml_tiers": {"sagemaker": "cooldown (299s left)", "s3-model": "open"}, "version": "1.0.0", "generated_at": "2026-09-18T09:14:40.836710Z"}

GET /version
{"version": "1.0.0", "generated_at": "2026-09-18T09:14:41.033597Z"}

GET /incident/SOS-3F5D3264   (a resolved, historical incident — read-only DynamoDB lookup, no data created)
{"zone_name": "Adyar", "created_at": "2026-09-02T06:32:42.383931Z", "dispatched_at": "2026-09-02T06:33:12.383931Z", "pincode": "600020", "status": "resolved", "reached_at": "2026-09-02T06:43:12.383931Z", "triggered_at": "2026-09-02T06:32:42.383931Z", "eta_seconds": 0, "updated_at": "2026-09-02T06:57:12.383931Z", "sos_id": "SOS-3F5D3264", "user_id": "citizen-702", "assigned_officer": "SI Arun Selvam", "events": [...5 events...], "assigned_patrol_id": "P003", "username": "Asha", "lat": 13.0036, "latitude": 13.0036, "lng": 80.2608, "longitude": 80.2608, "risk_level": "MEDIUM"}

GET /incident/SOS-3F5D3264/eta
{"sos_id": "SOS-3F5D3264", "status": "resolved", "assigned_patrol_id": "P003", "eta_seconds": 0, "distance_m": null, "patrol_position": null}

GET /police/citizens/active
{"total_count": 0, "by_pincode": [], "last_updated": "2026-09-18T09:15:09.372543+00:00Z", "note": "Current IST hour 14 is before after_hour=22"}

GET /police/route?from_lat=13.06&from_lng=80.27&to_lat=13.08&to_lng=80.24&sos_id=test
{"sos_id": "test", "destination": {"lat": 13.08, "lng": 80.24, "pincode": "600010", "area_name": "Vepery"}, "google_maps_url": "https://www.google.com/maps/dir/?api=1&origin=13.06,80.27&destination=13.08,80.24&travelmode=driving", "distance_km": 3.94, "eta_minutes": 13}
```

## Legacy / compatibility routes (20 routes)

Kept live, unchanged, so `citizen-app`/`police-app`/`dashboard` keep working
without a redeploy. New work should prefer the contract path where one
exists (column 4).

| Method | Path | Function | Contract equivalent | Currently called by |
|---|---|---|---|---|
| `POST` | `/sos/live` | `rakshak-sos-handler` | `POST /sos` | `apps/citizen-web` (fallback) |
| `GET` | `/sos/live` | `rakshak-sos-handler` | *(none — citizen's own feed)* | — |
| `POST` | `/sos/dispatch/{id}` | `rakshak-sos-handler` | *(none)* | — |
| `PATCH` | `/sos/resolve/{id}` | `rakshak-sos-handler` | `PATCH /incident/{id}/resolve` | `apps/police-web` (fallback) |
| `POST` | `/sos/cancelled` | `rakshak-sos-handler` | *(none — citizen cancel)* | — |
| `GET` | `/police/sos/active` | `rakshak-sos-handler` | `GET /incidents/active` | `dashboard`, `apps/police-web` |
| `PATCH` | `/police/sos/{sos_id}/status` | `rakshak-sos-handler` | `PATCH /incident/{id}/status` | `dashboard/src/config/api.js` |
| `GET` | `/patrols` | `rakshak-patrol-handler` | `GET /dashboard/patrols` | `dashboard` (`useLivePatrols`), `apps/police-web` |
| `PATCH` | `/patrols/{id}/status` | `rakshak-patrol-handler` | *(none)* | `dashboard/src/config/api.js` |
| `POST` | `/patrol/optimize` | `rakshak-patrol-handler` | *(none)* | `dashboard/src/config/api.js` |
| `GET` | `/heatmap/live` | `rakshak-dashboard` | `GET /dashboard/heatmap` | `dashboard` (`useRiskData`), `apps/citizen-web` |
| `GET` | `/prediction/zone/{zoneId}` | `rakshak-dashboard` | `GET /prediction/{zone}` | `dashboard/src/config/api.js` |
| `GET` | `/reports` | `rakshak-reports-handler` | *(none)* | `dashboard` (Reports panel) |
| `POST` | `/reports/submit` | `rakshak-reports-handler` | *(none)* | citizen apps (safety reports) |
| `PATCH` | `/reports/approve/{id}` | `rakshak-reports-handler` | *(none)* | `dashboard` (Reports panel) |
| `PATCH` | `/reports/reject/{id}` | `rakshak-reports-handler` | *(none)* | `dashboard` (Reports panel) |
| `GET` | `/police/citizens/active` | `rakshak-night-monitor` | *(none)* | police apps (night mode) |
| `POST` | `/citizens/ping` | `rakshak-night-monitor` | *(none)* | citizen apps (night mode heartbeat) |
| `GET` | `/police/route` | `rakshak-routing` | *(none)* | `apps/police-web` |
| `POST` | `/scan` | `rakshak-scan-inference` | *(none — orphaned)* | nothing; do not build against this |

## Undocumented live routes found this audit

| Method | Path | Function | Finding |
|---|---|---|---|
| `OPTIONS` | `/{proxy+}` | *(gateway-internal)* | Auto-generated CORS preflight catch-all. Not a content route, no action needed. |
| `POST` | `/score/refresh` | `rakshak-score-refresh` | **Live, callable, orphaned, and undocumented anywhere prior to this audit.** Verified via a real invocation 2026-09-18 (see `FRONTEND_INTEGRATION_GUIDE.md`). Returns a 44-zone array shaped `{pincode, safe_score (0..1 fraction — NOT 0-100), risk_level, confidence, zone, source}`. No frontend calls it; `dashboard`'s `useRiskData` polls `GET /heatmap/live` instead (confirmed in `AWS_RESOURCES.md`'s migration notes). **Recommendation: request deletion of this route + the `rakshak-score-refresh` Lambda from the backend team** — it's dead, undocumented, and its differently-scaled `safe_score` field is a footgun if anyone stumbles on it. |

## Status alias table (`PATCH .../status`)

| Accepted values | Canonical |
|---|---|
| `dispatched`, `assign`, `en_route` | `dispatched` |
| `reached`, `at_scene`, `atscene`, `arrived` | `reached` |
| `resolved`, `resolve`, `closed`, `done` | `resolved` |
| `cancelled`, `canceled`, `cancel` | `cancelled` |

Anything else → `400`. A terminal incident (`resolved`/`cancelled`) cannot
move back to a live state → `400`. Source: `rakshak-sos-handler.py`'s
`_STATUS_ALIASES` dict — verified byte-for-byte against `API_REFERENCE.md`,
no discrepancy found.

Patrol status (`PATCH /patrols/{id}/status`) uses a **completely different,
case-sensitive vocabulary** — `Patrolling`\|`Responding`\|`AtScene`\|`Returning`
only, no aliases. Don't reuse the incident alias table for patrol status
calls.

## Integration mismatches found (summary)

See `FRONTEND_INTEGRATION_GUIDE.md` for the full list with source citations.
Short version:
1. `POST /score/refresh` — live, orphaned, undocumented (above).
2. Route-count prose in `API_REFERENCE.md` (14+23) doesn't match `deploy/routes.py` (15+20) or the live count (37 total, reconciled above).
3. `safetyScore`/`riskLevel` (camelCase, prediction routes) vs. `safety_score`/`risk_level` (snake_case, heatmap/snapshot routes) — same score, two shapes, both permanent.
4. `DATABASE_SCHEMA.md`'s timeline event shape (`message`/`timestamp`) doesn't match the live shape (`detail`/`ts`) — see `API_MODELS.md`.
5. `rakshak-score-refresh` memory (1024MB live vs. 512MB documented) and alarm count (9 live vs. 7 documented) drift in `AWS_RESOURCES.md` — cosmetic, no frontend impact.

None required a backend code change; all are documentation/consistency
findings from comparing live state, source code, and existing docs.
