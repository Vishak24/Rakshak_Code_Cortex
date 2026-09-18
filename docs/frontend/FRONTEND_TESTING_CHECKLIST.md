# Frontend Testing Checklist

Every item references a real, live-verified endpoint from this audit
(2026-09-18). Use `docs/api-samples/` for expected shapes and
`shared/api/API_CONTRACT.json` as the machine-readable source when writing
assertions. Since **no route requires auth**, every check below can run
against the live base URL directly — no test-account setup needed. Prefer
running mutation tests (`POST /sos`, etc.) against a disposable pincode/test
identity rather than real-looking citizen data, since there is no
sandbox/staging API — `aksdwfbnn5` is the only environment.

## Citizen

- [ ] **SOS flow**: `POST /sos` with valid Chennai coordinates → expect `201`,
      `status` is `"dispatched"` if any unit is `Patrolling` (near-certain in
      the current 20-unit demo fleet), `assigned_patrol_id` non-null.
- [ ] **SOS flow — out of area**: `POST /sos` with `latitude: 45.0` → expect
      `400` with an `error` message naming the Chennai bounding box; confirm
      **no incident row is created** (this was a real prior bug — see
      `SECURITY_MODEL.md`).
- [ ] **SOS flow — missing body**: `POST /sos` with `{}` → expect `400`
      (`"request body must be a non-empty JSON object"`), not a `500`.
- [ ] **ETA updates**: after a successful `POST /sos`, poll
      `GET /incident/{id}/eta` every 2s and confirm `eta_seconds` decreases
      over time while `status` is `"dispatched"`, and reads `0` once
      `status` becomes `"reached"`.
- [ ] **Status updates**: confirm the citizen UI reflects `dispatched` →
      `reached` → `resolved` transitions purely from polling — no push
      mechanism exists, so a UI that doesn't re-render on the next poll tick
      is a bug in the UI, not the backend.
- [ ] **Cancel flow**: `POST /sos/cancelled` with a real, live `sos_id` →
      expect `200`, `{"message": "SOS cancelled", "sos_id": ...}`; confirm
      the assigned patrol's status flips to `Returning` on the next
      `GET /dashboard/patrols` poll.
- [ ] **Offline behavior**: disable network mid-poll and confirm the UI
      keeps showing the last-known incident state with a "reconnecting"
      indicator — **not** a blank/error screen, and definitely not a
      fabricated fresh-looking value (see `ERROR_HANDLING_GUIDE.md`'s
      anti-pattern citation against `apps/citizen-web`'s current
      `getZonePrediction()` fallback).
- [ ] **Zone prediction — out of coverage**: `GET /prediction/999999` →
      expect `404`, UI shows "outside coverage," not a crash.
- [ ] **Night-mode ping**: `POST /citizens/ping` → expect `200`,
      `{"status": "ok"}`; confirm it's fire-and-forget (no loading spinner
      blocking the UI on this call).

## Police

- [ ] **Active incidents feed**: `GET /incidents/active?officer_lat=13.06&officer_lng=80.27`
      → expect an array sorted ascending by `distance_km`, capped at 50
      rows; confirm the police UI's list order matches server order (don't
      re-sort client-side, or the "sort by distance" behavior can silently
      diverge from the backend's).
- [ ] **Accept incident**: `PATCH /incident/{id}/accept` with a real
      `sos_id` → expect `200`, `accepted_at` set; confirm the incident's
      `status` is **unchanged** by this call (accept is acknowledgment-only,
      not a status transition — a UI that flips to "accepted" as a new
      status is misrepresenting the backend).
- [ ] **Status progression**: `PATCH /incident/{id}/status` with
      `{"status": "reached"}` on a `dispatched` incident → expect `200`,
      partial response `{sos_id, status: "reached", assigned_patrol_id}`;
      **confirm the UI refetches `GET /incident/{id}` afterward** rather
      than trusting the partial `PATCH` response as the full incident state.
- [ ] **Status progression — invalid transition**: `PATCH .../status` with
      `{"status": "dispatched"}` on an already-`resolved` incident → expect
      `400` (terminal states cannot move back to a live state).
- [ ] **Status progression — unknown value**: `PATCH .../status` with
      `{"status": "banana"}` → expect `400` listing the valid canonical set.
- [ ] **Resolve**: `PATCH /incident/{id}/resolve` → expect `200`,
      `status: "resolved"`; confirm the incident **disappears from the next
      `GET /incidents/active` poll** (it's filtered to `LIVE_STATES` only)
      and the assigned patrol's status flips to `Returning`.
- [ ] **Route to scene**: `GET /police/route?from_lat=&from_lng=&to_lat=&to_lng=&sos_id=`
      → expect a `google_maps_url` field; confirm the UI opens it externally
      rather than trying to render turn-by-turn geometry from this response
      (there is none — see `MAP_INTEGRATION_GUIDE.md`).
- [ ] **Night-mode citizen monitor**: `GET /police/citizens/active` during
      daytime IST hours → expect `total_count: 0` with an explanatory
      `note` field; confirm the UI shows a calm empty state, not an error,
      for this expected-empty case.

## Dashboard

- [ ] **Patrol movement**: poll `GET /dashboard/patrols` twice, 3+ seconds
      apart, for a `Patrolling` unit → confirm `position` changes between
      polls (server-computed from elapsed time, never static) and that the
      marker animates smoothly between the two polled positions rather than
      jumping (verify `VITE_MARKER_LERP_MS`-based interpolation is applied).
- [ ] **Patrol movement — responding unit**: for a unit with
      `status: "Responding"`, confirm `distance_m` and `eta_seconds` both
      decrease across consecutive polls, and that `distance_m` is **absent**
      once the unit's status is anything other than `Responding` (don't
      assume it's always present — see `API_MODELS.md`).
- [ ] **Timeline updates**: trigger a real status transition (via the
      police checklist above) and confirm the new event appears at the top
      of the next `GET /dashboard/timeline` poll within one poll interval
      (5s), with `type`/`ts`/`detail` fields populated — **not**
      `message`/`timestamp` (the shape `DATABASE_SCHEMA.md` describes is
      stale; see `API_MODELS.md`'s correction).
- [ ] **Heatmap updates**: confirm `GET /dashboard/heatmap` returns exactly
      44 zones (`zone_count: 44`) every time, and that `safety_score`
      responds (drops) when a new incident is created in that zone within
      the current IST day (the `-6`/incident-today, `-10`/active-incident
      density penalty in `_zone_scores()`).
- [ ] **Analytics refresh**: confirm `GET /dashboard/snapshot`'s
      `high_risk_zones` is always exactly the top 5 by `safety_score`
      ascending (most dangerous first), not all 44 — a UI rendering more
      than 5 rows from this field is reading it wrong.
- [ ] **Reports panel**: `GET /reports` → confirm pending reports render;
      `PATCH /reports/approve/{id}` / `PATCH /reports/reject/{id}` → confirm
      the report disappears from the pending list on next fetch. (These two
      PATCH responses were **not captured live this audit** — their shape
      in `API_CONTRACT.json` is inferred, not observed; flag any mismatch
      found while implementing this test as a fresh finding, not an
      already-known one.)
- [ ] **Health/version surfaces** (if the dashboard exposes an ops/debug
      panel): `GET /health` → confirm the UI reads `body.status`
      (`"ok"`/`"degraded"`) rather than only the HTTP status code, since
      `/health` returns `200` even when degraded.

## Cross-cutting (all three apps)

- [ ] Confirm every app's `.env`/build config points at
      `https://aksdwfbnn5.execute-api.ap-south-1.amazonaws.com` with **no**
      stage path segment — a hardcoded `/prod` or `/dev` prefix will 404
      everything.
- [ ] Confirm no app sends an `Authorization` header expecting it to matter
      — there's no authorizer to reject or accept it either way, so a
      missing/garbage token won't surface as a bug here, but don't build a
      test that asserts auth-gated behavior that doesn't exist.
- [ ] Confirm CORS preflight (`OPTIONS`) succeeds from each app's actual dev
      origin (`localhost:3000`/`3001`/`3002` per each `package.json`'s
      `dev` script) — the API's CORS is `AllowOrigins: *`, so this should
      never fail, but a browser-side proxy/rewrite misconfiguration could
      still break it locally.
- [ ] Confirm no test or app code calls `POST /score/refresh` or `POST /scan`
      — both are live but orphaned/undocumented; a test asserting behavior
      against either is testing dead code (see `API_ENDPOINT_REFERENCE.md`).
