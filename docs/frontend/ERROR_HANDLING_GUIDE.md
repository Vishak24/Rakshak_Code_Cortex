# Error Handling Contract

**The backend emits exactly three status codes: `400`, `404`, `500`** (plus
`200`/`201` for success). Verified by reading every `lambda_function.py` in
`backend/lambdas/` — every handler's router is wrapped in a bare
`try/except Exception` that returns `rc.server_error(e)` (a `500`), and
every explicit error path calls `rc.bad_request()` (`400`) or
`rc.not_found()` (`404`). **There is no `409`** — auto-dispatch uses a
DynamoDB `ConditionExpression` internally and silently falls through to the
next-nearest patrol on contention; it never surfaces a conflict to the
caller. There is no application-level `429` — API Gateway account-level
throttling could theoretically produce one, but no per-route throttle is
configured (`ThrottleSettings` unset, confirmed live), so in practice you
will not see it under normal load. `502`/`503`/`504` can only come from API
Gateway itself (Lambda cold-start failure, function timeout at 30s, a
malformed Lambda response) — never from application code.

Every error body has the same shape: `{"error": "<message>"}`. There is no
error code/enum field — only a free-text message. **Do not switch UI
behavior on the message string** (it can change); switch on the HTTP status
code and the route.

## Centralized error table

| HTTP status | Meaning here | Frontend behavior | User-facing message | Retry? |
|---|---|---|---|---|
| `400` | Malformed/invalid request — missing required field, out-of-Chennai-bounding-box coordinate, unrecognized status value, terminal-incident transition | Show inline form/action error using the server's `error` message (it's already human-readable, e.g. `"latitude 45.0 is outside the Chennai service area (12.7, 13.4)"`) | Server message, verbatim, is usually fine to show directly | No — it's a client bug or bad input; retrying the same request 400s again |
| `404` | Unknown `sos_id`/`patrol_id`/`incident_id`, or a pincode outside the 44 serviced zones | Show a "not found" empty state, not a generic error screen | `"This report or ID could not be found — it may have been resolved already."` (incident) / `"This area is outside Rakshak's current coverage."` (prediction) | No |
| `500` | Unhandled backend exception — the handler itself caught something it didn't expect | Show a generic retry-able error banner | `"Something went wrong on our end. Please try again."` | Yes — on next poll tick (GET) or a manual retry button (mutation) |
| `502`/`503`/`504` | Gateway-level failure (Lambda cold-start crash, 30s timeout, malformed response) — not emitted by application code | Same as 500, but this pattern recurring should be escalated to backend/infra, not treated as a normal error | `"The service is temporarily unavailable. Please try again shortly."` | Yes, with a short delay (a few seconds) — a 30s Lambda timeout means the *next* call is likely to hit a warm container and succeed |
| `429` | API Gateway account-level throttling (theoretical — no per-route throttle configured today) | Same as 500/503 | `"Too many requests — please wait a moment."` | Yes, with backoff |

**Note on the task brief's example codes:** `409 Patrol Already Assigned`
and `500 ML Inference Failed` (as distinct, labeled cases) don't exist as
such in this backend — auto-dispatch degrades silently (no 409), and ML
inference failure is invisible to the caller by design (the 3-tier
`predict_batch()` resolver falls through to a deterministic baseline and
still returns `200` — see `source: "baseline"` in `PredictionModel`). Treat
those as illustrative categories from the task brief, not this backend's
actual contract; the table above is what's real.

## Per-endpoint error notes worth calling out specifically

- **`POST /sos`** — a `400` here means the incident was *not* created (no
  junk row left behind — this was a real bug in a previous version,
  documented and fixed per `SECURITY_MODEL.md`). Safe to let the citizen
  correct and resubmit.
- **`PATCH /incident/{id}/status`** — `400` on an unrecognized status value
  lists the valid canonical set in the message itself (`"status must be one
  of ['cancelled', 'dispatched', 'reached', 'resolved'], got 'banana'"`) —
  safe to surface directly, or map it to the alias table in
  `API_ENDPOINT_REFERENCE.md` for a friendlier message.
- **`GET /prediction/{zone}`** — `404` means the pincode isn't one of the 44
  serviced Chennai zones (`rc.is_known_zone()`), not that the backend is
  broken. Don't retry; show "outside coverage."
- **`GET /health`** returns `200` even when degraded — **the frontend must
  read `body.status`**, not just the HTTP status code, to detect a problem.
  A `500`-style banner for `GET /health` is wrong; a `"degraded"` body on a
  `200` response should surface as a soft warning, not a hard error.

## Anti-pattern found in the current codebase — do not repeat

`apps/citizen-web/src/services/api.js`'s `getZonePrediction()` catches
**any** error (network failure, 404, 500 — all of them) and returns a
fabricated literal:

```js
// apps/citizen-web/src/services/api.js — DO NOT copy this pattern
catch (err) {
  return { pincode, zoneName: '...', safetyScore: 84, riskLevel: 'LOW', confidence: 0.94, source: 'Lambda ML Local' };
}
```

This can show a citizen "LOW risk, 84% safe" during a genuine outage or for
an out-of-coverage pincode, which is actively misleading for a safety app.
The correct pattern is already implemented in every `dashboard/src/hooks/*.js`
hook: keep the last known real value, set an `error` field, let the UI
decide how to represent staleness (e.g., a "last updated 40s ago" badge)
rather than inventing a fresh-looking fake reading. Apply the hooks'
pattern, not the web-app services' pattern, when `apps/citizen-web` and
`apps/police-web` are built out further.

## Loading / empty / retry / timeout UI — lightweight recommendations

| Endpoint category | Skeleton | Empty state | Retry UI | Timeout UI |
|---|---|---|---|---|
| Lists (`/incidents/active`, `/patrols`, `/dashboard/timeline`, `/reports`) | Row-shaped skeleton, 3–5 rows | "No active incidents right now" / "No patrols assigned" — a calm, positive-framed empty state, not an error look | Not needed — next poll tick handles it silently; show a small "reconnecting…" indicator only after 2 consecutive failed polls | N/A (polling) |
| Single-resource (`/incident/{id}`, `/prediction/{zone}`) | Card-shaped skeleton | 404 → "not found" state (see table above) | Explicit "Retry" button on `500`/`5xx` | After 8s client timeout, show the retry UI, not an infinite spinner |
| Mutations (`POST /sos`, `PATCH .../status`, `.../resolve`, `.../accept`) | Button loading spinner, disable double-submit | N/A | Explicit "Try again" button on failure — never auto-retry a mutation (see `POLLING_AND_REALTIME.md`) | Disable the button for the full 8s client timeout so a slow request can't be double-submitted |
| Heatmap/snapshot (dashboard) | Skeleton matching the 44-zone grid / stat-card layout | N/A (always returns all 44 zones / all counters) | Keep last-known grid + small error banner (already implemented in `useRiskData.js`) | Same |
