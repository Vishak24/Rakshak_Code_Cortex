# Polling & Realtime Strategy

**No WebSockets** — the backend is HTTP API (API Gateway v2) with plain
request/response Lambda integrations, no `$connect`/`$disconnect` routes, no
API Gateway WebSocket API, confirmed via `aws apigatewayv2 get-apis` (only
`aksdwfbnn5`, `ProtocolType: HTTP`). Every "live" surface in every existing
app is polling. This is the correct strategy to keep using — do not
introduce WebSockets or SSE without a backend change, and there's no
evidence the traffic volume here needs one (patrol/incident counts are in
the tens, not thousands).

All intervals below are **already implemented and verified**, not proposed —
either running live in `dashboard/src/hooks/*.js`, or declared in the root
`.env.example` as the convention every app should follow.

## Citizen

| What | Endpoint | Interval | Starts | Stops |
|---|---|---|---|---|
| My active SOS feed | `GET /sos/live?user_id=` | 2000ms (`VITE_POLL_SOS_FEED_MS`) | On raising an SOS (`POST /sos` succeeds) | When the SOS reaches `resolved`/`cancelled`, or the citizen navigates away |
| Single-incident tight ETA | `GET /incident/{id}/eta` | 2000ms (`VITE_POLL_MY_INCIDENT_MS`) | When a specific `sos_id` is being tracked (post-creation screen) | Same as above |
| Zone safety score (map/home screen) | `GET /prediction/{zone}` | 15000ms (`VITE_POLL_PREDICTION_MS`) | On viewing a zone's safety card | On leaving the screen |

**Retry strategy:** every existing `fetch`/`axios` call in this codebase
uses an 8-second client timeout (`AbortSignal.timeout(8000)` in the
`dashboard` hooks, `axios.create({timeout: 8000})` in `apps/*/src/services`)
and **no automatic retry beyond the next scheduled poll tick** — a failed
poll just waits for the next interval. This is correct for a 2–15s polling
cadence: an explicit retry-with-backoff on top of a 2s poll loop adds
complexity without benefit (the next tick *is* the retry). Keep this
pattern; do not add exponential backoff to a foreground poll loop shorter
than ~5s.

**Offline strategy:** `apps/citizen-web/src/services/api.js` already
demonstrates the wrong pattern to avoid — on error, `getZonePrediction()`
falls back to a **fabricated** `{safetyScore: 84, riskLevel: 'LOW', ...}`
literal. This can show a citizen a false "safe" reading during a real
outage. The correct pattern, already implemented in every `dashboard/src/hooks/*.js`
hook, is: **on fetch failure, keep the last known live value and surface an
`error` field** — never substitute an invented number. Apply this
consistently once `apps/citizen-web`/`apps/police-web` are built out; see
`ERROR_HANDLING_GUIDE.md` for the specific anti-pattern citation.

For a citizen with no connectivity at all (native mobile, not web): queue
the `POST /sos` body locally and retry on reconnect (standard offline-queue
pattern) — there's nothing backend-specific here since the endpoint is
idempotent-safe to retry (a retried `POST /sos` creates a *second* incident,
so de-duplicate client-side with a locally-generated request id before
retrying, since the backend does not currently accept or check one).

## Police

| What | Endpoint | Interval | Notes |
|---|---|---|---|
| Active incidents feed | `GET /incidents/active` | 2000ms (`VITE_POLL_SOS_FEED_MS`) | Verified live in `dashboard/src/hooks/useActiveIncidents.js`; sort by `distance_km` to `officer_lat`/`officer_lng` is server-side |

**Refresh strategy:** the police view is a single continuously-polled list;
there is no separate "refresh" gesture needed beyond the poll itself. If a
manual pull-to-refresh is added (mobile UX convention), it should just
trigger the same fetch function out of cycle, not a different endpoint.

**Conflict handling:** two officers can both call `PATCH
/incident/{id}/status` concurrently — the backend has **no optimistic
concurrency control on incident status** (no `ConditionExpression`,
confirmed in `rakshak-sos-handler.py`'s `_set_status()`); the last write
wins. The one place the backend *does* guard against a race is patrol
assignment (`assign_nearest_patrol`'s `ConditionExpression` prevents two
citizens' SOS from grabbing the same unit). For the frontend: after any
`PATCH`, **always refetch** `GET /incident/{id}` (the `PATCH` responses are
partial — see `API_MODELS.md`) rather than trusting the `PATCH` response as
the new source of truth, so a stale local write doesn't linger in the UI
past the next poll tick.

## Dashboard

All five, verified live in `dashboard/src/hooks/`:

| What | Endpoint | Interval | Env var | Hook |
|---|---|---|---|---|
| Patrols | `GET /dashboard/patrols` (legacy: `/patrols`) | 3000ms | `VITE_POLL_PATROLS_MS` | `useLivePatrols.js` |
| Active incidents | `GET /incidents/active` (legacy: `/police/sos/active`) | 2000ms | `VITE_POLL_SOS_FEED_MS` | `useActiveIncidents.js` |
| Snapshot (headline counters) | `GET /dashboard/snapshot` | 5000ms | `VITE_POLL_DASHBOARD_SNAPSHOT_MS` | `useSnapshot.js` |
| Timeline | `GET /dashboard/timeline` | 5000ms | *(hardcoded — see gap below)* | `useTimeline.js` |
| Heatmap | `GET /dashboard/heatmap` (legacy: `/heatmap/live`) | 10000ms | `VITE_POLL_HEATMAP_MS` | `useRiskData.js` |

**Found gap:** `useTimeline.js` hardcodes `5000` instead of reading a
`VITE_POLL_*_MS` env var like the other four hooks — inconsistent with the
established convention, low priority (5s is already a sensible default;
this is a maintainability note, not a bug).

**Animation recommendation:** `VITE_MARKER_LERP_MS=3000` is already declared
in `.env.example` for client-side interpolation of patrol markers between
3-second polls, so movement reads as smooth instead of jumping every 3s.
This is a pure frontend concern — the backend has no animation/tweening
capability, it returns instantaneous positions on each poll. Recommended:
`requestAnimationFrame`-driven lerp from last-known to newly-polled
position over `VITE_MARKER_LERP_MS`, capped so a lerp in progress is
abandoned (not queued) if a new poll result arrives first.

**Why not tighten the heatmap/snapshot intervals further:** `/dashboard/heatmap`
and `/dashboard/snapshot` both call `predict_batch()` across all 44 zones
in one Lambda invocation (verified in `rakshak-dashboard/lambda_function.py`
`_zone_scores()`) — cheap per the `OBSERVABILITY.md` performance budget
(~150ms warm), but a real, budgeted DynamoDB scan (`rc.scan_all`) backs
every one of these calls with no GSI on `rakshak-sos-alerts` for the
snapshot/timeline access pattern (only `/incidents/active`-style queries
benefit from the `status-created_at-index` GSI — see `DATABASE_SCHEMA.md`).
10s/5s is already tuned to this; don't drop below it without confirming the
scan cost with the backend team first.

## Cross-cutting: retry/backoff policy for all three apps

1. Client-side request timeout: **8 seconds**, matching every existing
   implementation. Don't go lower — cold-start + DynamoDB scan can
   legitimately take longer than the ~150ms warm budget on the very first
   call after idle (see `OBSERVABILITY.md`'s keep-warm rule, which mitigates
   but doesn't eliminate this for the 4 contract-serving functions).
2. On failure: keep last-known good value, set an `error` field, let the
   next scheduled poll retry. Do not fabricate a fallback value (see
   Citizen section above).
3. No exponential backoff on any poll loop under 5s — the fixed interval
   already behaves like a retry loop with a floor.
4. A `POST`/`PATCH` mutation is never retried automatically on failure — surface
   the error to the user and let them re-trigger the action (a person tapping
   "resolve" twice because the first attempt silently retried is worse than
   a visible failure with a retry button).
