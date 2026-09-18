# Map Integration Specification

No new map assets are created by this audit — this documents what already
exists and which layer's data comes from the live API vs. a bundled static
file.

## Map libraries in use

| App | Library | Evidence |
|---|---|---|
| `dashboard`, `apps/citizen-web`, `apps/police-web` | `leaflet` + `react-leaflet`; `leaflet.heat` (dashboard + citizen-web only) | `package.json` dependencies, confirmed identical versions across all three |
| `citizen-app`, `police-app` (Flutter) | `flutter_map` + `latlong2` | `pubspec.yaml` |

## Data sources — API vs. bundled asset

| Layer | Source | Endpoint (if API) | Bundled file (if asset) |
|---|---|---|---|
| Patrol unit markers (live position) | **API, polled** | `GET /dashboard/patrols` (`/patrols` legacy) | — position is *never* a static asset; it's server-computed on every read from `assets/patrol_routes.json`'s waypoints + elapsed time (see `backend/lambdas/_shared/rakshak_common.py`'s `compute_patrol_view()`) |
| Active incident markers | **API, polled** | `GET /incidents/active` (`/police/sos/active` legacy) | — |
| Heatmap intensity/color per zone | **API, polled** | `GET /dashboard/heatmap` (`/heatmap/live` legacy) | — |
| Zone boundary polygons (for a polygon-fill map instead of a point heatmap) | **Bundled asset** | — | `assets/chennai_zones.geojson` (backend copy: `backend/lambdas/_shared/chennai_zones.geojson`, used server-side for `zone_for_point()`; frontend copies: `citizen-app/assets/`, `police-app/assets/`, `dashboard/public/chennai-zones-{fixed,osm}.geojson`) |
| Patrol route waypoints (the loop each unit patrols) | **Bundled asset**, mirrored server-side | — | `assets/patrol_routes.json` — this is a *reference copy*; the backend's authoritative version is `PATROL_UNITS` in `rakshak_common.py` (hardcoded, not read from this file at runtime). If a route is ever changed, it must be changed in `rakshak_common.py` for the backend to actually move patrols differently — editing `assets/patrol_routes.json` alone has no runtime effect. |
| Pincode boundary reference (KML) | **Bundled asset**, display/lookup only | — | `Final_Chennai_Pincode.kml`, `chennai-pincodes.kml` (root `assets/`, `dashboard/public/`, both Flutter apps) |

## Which map layer consumes which endpoint

- **RiskHeatmap** (`dashboard/src/components/RiskHeatmap`): consumes
  `useRiskData()` → `GET /heatmap/live`. Each of the 44 zones' `lat`/`lng`
  centroid (from the API response itself, not the GeoJSON) plus
  `heatWeight = 1 - safety_score/100` feeds `leaflet.heat`. **The API
  already returns per-zone centroids** — the GeoJSON polygons are not
  required to render the heat layer, only needed if a polygon-fill
  (choropleth) rendering is preferred over `leaflet.heat`'s point-intensity
  rendering.
- **Patrol markers**: `useLivePatrols()` → `GET /dashboard/patrols`, one
  marker per unit, `position` field. Marker rotation/heading can use the
  `heading` field (`patrol`\|`to_scene`\|`on_scene`\|`returning`) as a
  simple icon-state switch, not a real compass bearing.
  `VITE_MARKER_LERP_MS` (see `POLLING_AND_REALTIME.md`) drives client-side
  smoothing between polls.
- **Incident markers**: `useActiveIncidents()` → `GET /incidents/active`,
  one marker per live incident, using `latitude`/`longitude` (fall back to
  `lat`/`lng` — see `API_MODELS.md`).
- **Zone boundary polygons**: rendered directly from the bundled GeoJSON,
  never fetched from the API. The backend has no "get zone polygons"
  endpoint — `rakshak-zones` DynamoDB table exists but has 0 items and is
  not read by any Lambda (`DATABASE_SCHEMA.md`); the GeoJSON file is the
  actual source of truth for polygon geometry on both frontend and backend.

## Heatmap color mapping

Consistent across every app that renders one: `risk_level` (`LOW`/`MEDIUM`/`HIGH`)
maps to a fixed 3-color scale, already defined in `dashboard/src/App.jsx`:

```js
const RISK_COLOR = { HIGH: '#FF3B5C', MEDIUM: '#F59E0B', LOW: '#22C55E' }
```

For a continuous (non-banded) heat layer, use `safety_score`/`safetyScore`
directly (0–100, higher = safer) rather than re-deriving it from
`risk_level` — the two are guaranteed consistent
(`rakshak_common.safety_to_level()` is the single source of both, per
`AWS_ARCHITECTURE.md`), but the raw score gives smoother gradients than the
3-band label.

**Important inversion, already handled correctly in
`dashboard/src/hooks/useRiskData.js`:** the API's `safety_score` is
*safety* (high = safe), but a heat layer conventionally wants a *danger*
weight. The existing, correct transform is:

```js
heatWeight = Math.max(0, Math.min(1, 1 - safety_score / 100))
```

Do not feed `safety_score` directly into `leaflet.heat` as the weight — that
would paint the safest zones as the hottest.

## Finding: dashboard's local zone-name fallback table disagrees with the backend

`dashboard/src/constants/zones.js` (a hand-authored `ZONES` array used to
build `useActiveIncidents.js`'s `PINCODE_NAME` lookup, for when a live
`zone_name` comes back as a bare pincode — the documented "naming trap" in
`DATABASE_SCHEMA.md`) **assigns different area names to the same pincodes
than the backend's authoritative `rakshak_common.ZONE_NAMES`**, e.g.:

| Pincode | `dashboard/src/constants/zones.js` says | Backend `rakshak_common.ZONE_NAMES` says |
|---|---|---|
| `600001` | "Park Town" | "Parrys" |
| `600002` | "Sowcarpet" | "Anna Salai" |
| `600003` | "Royapuram" | "Park Town" |
| `600004` | "Chintadripet" | "Mylapore" |
| `600006` | "Triplicane" | "Nungambakkam" |

Only 2 of 13 spot-checked pincodes happened to agree. **This is a real,
user-facing risk**: whenever the live `zone_name` field is a bare pincode
(confirmed to happen — see `API_MODELS.md`'s patrol `P008` example,
`zone_name: "600023"`), the dashboard falls back to *this* table and can
display a materially wrong area name to a police dispatcher. Recommendation:
replace `dashboard/src/constants/zones.js`'s pincode→name mapping with
`rakshak_common.ZONE_NAMES` (44 entries, already enumerated in this repo at
`backend/lambdas/_shared/rakshak_common.py` lines ~308–324) so client-side
and server-side names can never disagree. This is a frontend-only fix (a
constants file), not a backend change.
