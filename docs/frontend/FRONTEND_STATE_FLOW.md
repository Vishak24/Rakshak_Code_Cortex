# Frontend State Flow — Screen → Backend Mapping

Screen inventory below is read from the actual repo structure
(`citizen-app/lib/features/`, `police-app/lib/features/`,
`dashboard/src/components/` + `App.jsx`), not invented — `citizen-app` and
`police-app` share an identical feature-folder shape (`sos`, `alerts`, `map`,
`intelligence`, `sentinel`, `user_space`, `auth`), which this doc uses as the
screen boundary for both Flutter apps and their web counterparts
(`apps/citizen-web`, `apps/police-web`).

No UI implementation is prescribed here — only which backend calls each
screen needs, when they fire, and what the three loading/empty/error states
should show (details in `ERROR_HANDLING_GUIDE.md`).

## Citizen App / `apps/citizen-web`

| Screen (feature) | API calls | Trigger | Polling | Cached state | Loading | Error | Empty |
|---|---|---|---|---|---|---|---|
| **SOS** (`features/sos`) | `POST /sos` | User taps the SOS button | — | Last-submitted `sos_id` (for the ETA screen) | Disable button, spinner, prevent double-tap | Inline banner with server `error` message; button re-enables | N/A |
| **SOS tracking / ETA** | `GET /incident/{id}/eta`, fallback `GET /incident/{id}` | On successful `POST /sos` | 2000ms (`VITE_POLL_MY_INCIDENT_MS`) while status is live | Last-known `eta_seconds`/`patrol_position` | Skeleton card on first load only | Keep last-known + small "reconnecting" indicator after 2 failed polls | N/A — always has the one incident just created |
| **My active SOS feed** | `GET /sos/live?user_id=` | Screen mount | 2000ms (`VITE_POLL_SOS_FEED_MS`) | Last-known list | Row skeletons | Keep last list + error badge | "No active SOS" |
| **Alerts** (`features/alerts`) | `GET /sos/live?user_id=` (historical view, same endpoint, client-side filter to terminal states) | Screen mount | Not polled (historical) | Full list, refresh on pull | Row skeletons | Retry button | "No past alerts" |
| **Map / Safety score** (`features/map`, `features/intelligence`) | `GET /prediction/{zone}` for the viewed zone; `GET /heatmap/live` or `/dashboard/heatmap` if a full-city view exists | Zone selection / screen mount | 15000ms (`VITE_POLL_PREDICTION_MS`) for the single zone card | Last-known score | Skeleton score card | **Keep last-known — never fabricate a score** (see `ERROR_HANDLING_GUIDE.md` anti-pattern) | N/A (always answers or 404s) |
| **Sentinel** (night-mode heartbeat, `features/sentinel`) | `POST /citizens/ping` | Periodic background timer while night mode is on (interval not backend-specified — this is a client-only cadence choice) | N/A (fire-and-forget writes) | N/A | Silent (no UI blocking) | Silent retry on next scheduled ping — a missed heartbeat isn't user-facing | N/A |
| **Safety reports** (part of `user_space` or a dedicated report flow) | `POST /reports/submit` | User submits a report | — | Submitted report id/status | Button spinner | Inline error, allow resubmit | N/A |
| **Auth** (`features/auth`) | *(none — there is no login backend)* | — | — | — | — | — | — |

## Police App / `apps/police-web`

| Screen (feature) | API calls | Trigger | Polling | Cached state | Loading | Error | Empty |
|---|---|---|---|---|---|---|---|
| **Active incidents feed** (`features/sos`, `features/alerts`) | `GET /incidents/active?officer_lat=&officer_lng=` | Screen mount, and on obtaining device GPS | 2000ms (`VITE_POLL_SOS_FEED_MS`) | Last-known sorted list | Row skeletons | Keep last list + banner | "No active incidents nearby" |
| **Accept / acknowledge incident** | `PATCH /incident/{id}/accept` | Officer taps "Accept" | — | Optimistic local flag; confirm via next poll | Button spinner | Inline error, allow retry | N/A |
| **Status progression** (dispatched → reached → resolved) | `PATCH /incident/{id}/status` (or the `/accept`/`/resolve` shorthands) | Officer action | — | Optimistic local status; **must refetch `GET /incident/{id}` after — PATCH responses are partial** (see `API_MODELS.md`) | Button spinner, disable during in-flight PATCH | Inline error with retry; do not auto-retry (`ERROR_HANDLING_GUIDE.md`) | N/A |
| **Resolve incident** | `PATCH /incident/{id}/resolve` | Officer taps "Resolve" | — | Removes incident from active feed on next poll | Button spinner | Inline error | N/A |
| **Route to scene** (`features/map`) | `GET /police/route?from_lat=&from_lng=&to_lat=&to_lng=&sos_id=` | Officer taps "Navigate" | — (one-shot) | Last route response | Spinner on the navigate button | Retry button | N/A |
| **Night-mode citizen monitor** (`features/sentinel`) | `GET /police/citizens/active` | Screen mount, officer on night shift | Suggest matching citizen's ping cadence, or 30–60s (not backend-specified) | Last-known count/list | Row skeletons | Keep last-known | `total_count: 0` is a normal, common state (backend explains why in the `note` field — safe to show in a debug view, not to an end user as-is) |
| **Patrol status override** (ops/testing) | `PATCH /patrols/{id}/status` | Manual override action | — | N/A | Button spinner | Inline error | N/A |

## Central Command Dashboard (`dashboard/`)

Already built and wired — this table documents the existing, verified
implementation rather than proposing one.

| Screen/panel (component) | API calls | Trigger | Polling | Cached state | Loading | Error | Empty |
|---|---|---|---|---|---|---|---|
| **RiskHeatmap** | `GET /heatmap/live` (legacy path; contract path `/dashboard/heatmap` is byte-identical) | Mount + `refetch()` from Sidebar | 10000ms (`VITE_POLL_HEATMAP_MS`), `useRiskData.js` | Full `Map<pincode, zone>` retained on error | `loading` flag exposed by the hook | `error` field, grid keeps last values | N/A (always 44 zones) |
| **AlertsPanel / active incidents** | `GET /incidents/active` (via `/police/sos/active` today) | Mount | 2000ms, `useActiveIncidents.js` | `incidents` (live) + `history` (last 25 departed) | Row skeletons | `error` field | "No active incidents" |
| **PatrolStats / map markers** | `GET /dashboard/patrols` (via `/patrols` today) | Mount | 3000ms, `useLivePatrols.js` | Last-known `patrols` array, optimistic `updatePatrolStatus()` | Marker fade-in | Silently keeps last positions (no explicit error UI in the hook today — worth adding) | N/A (always 20 units) |
| **StatsCard row** | `GET /dashboard/snapshot` | Mount | 5000ms, `useSnapshot.js` | Last snapshot | Skeleton stat cards | `error` field | N/A |
| **IncidentTimeline** | `GET /dashboard/timeline?limit=40` | Mount | 5000ms (hardcoded — see `POLLING_AND_REALTIME.md` gap), `useTimeline.js` | Last `events` array | Row skeletons | Silently keeps last events (no explicit error surfaced — same gap as PatrolStats) | "No recent activity" |
| **SafetyScorePanel** | `GET /prediction/{zone}` (legacy: `/prediction/zone/{zoneId}`) for `selectedZone` (defaults to `600017`, T. Nagar) | Zone selection in `App.jsx` `selectedZone` state | Not confirmed wired to `VITE_POLL_PREDICTION_MS` — declared in `.env.example` but no dedicated hook found this pass | Last score for the selected zone | Skeleton score panel | Keep last score | N/A |
| **PatrolDetailPanel** | *(none — derived client-side from the already-polled `patrols` array via `selectedPatrolId`)* | Marker/list click | — | — | — | — | — |
| **Reports panel** | `GET /reports`, `PATCH /reports/approve/{id}`, `PATCH /reports/reject/{id}` | View switch to `activeView === 'reports'` | Not polled (manual refresh implied) | Last-fetched list | Row skeletons | Retry button | "No pending reports" |

## Cross-app note: `apps/citizen-web` and `apps/police-web` are pre-wired but unstyled/incomplete

Both already have a working `axios`-based `services/api.js` hitting the live
API with sane fallbacks (contract path → legacy path). The screen tables
above describe the target state for these two once their UI is built out;
they are not starting from zero on the API integration side, only on
screens/components. Reuse `dashboard/src/hooks/*.js`'s polling pattern
(keep-last-known, `error` field, `AbortSignal.timeout(8000)`) rather than
`apps/*/src/services/api.js`'s current per-call try/catch-with-fallback
pattern, once a shared `polling_service.ts` exists (see
`FRONTEND_INTEGRATION_GUIDE.md`'s API client architecture section).
