# Patrol Simulation

20 simulated patrol units cover Chennai. Every unit's position is
**computed on read, never stored** — there is no scheduler, no cron job, no
background worker ticking positions forward. `GET /patrols` (and every
other read that needs a patrol's live position) calls
`rakshak_common.compute_patrol_view(row, now)`, which derives the current
position from a single anchor timestamp plus elapsed wall-clock time.

This is the same trick a video player uses for a live progress bar: store
where playback started and at what time, then compute "now" from
`elapsed = wall_clock_now - start_ts`. No per-tick writes, no drift from a
missed cron run, and any number of concurrent readers get a consistent
answer without coordinating with each other.

## The 4 states

| Status | Meaning | Position derivation |
|---|---|---|
| `Patrolling` | On its assigned route, looping | `position_on_route(waypoints, elapsed_since(cycle_start_ts) * speed)` — walks the route polyline at `PATROL_SPEED_KMPH` (40 km/h default), wrapping at the end |
| `Responding` | Diverted to an SOS | `lerp_toward(divert_from, sos_target, divert_start_ts, DIVERT_SPEED_KMPH)` — straight-line interpolation at 55 km/h (faster than patrol speed — this is an emergency response) |
| `AtScene` | Arrived at the SOS location | position pinned to the SOS coordinates, `eta_seconds = 0` |
| `Returning` | Released, heading back to its route's start waypoint | `lerp_toward(return_from, route[0], return_start_ts, PATROL_SPEED_KMPH)` |

## Route data

`assets/patrol_routes.json` — 20 units, each with an ordered list of
`[lat, lng]` waypoints forming a loop. `rakshak_common.PATROL_UNIT_BY_ID`
loads this at import time; a DynamoDB row can override its route via a
`route` attribute, falling back to the static roster otherwise
(`patrol_route_waypoints()`).

## Auto-assignment (the "nearest free patrol" engine)

`assign_nearest_patrol(sos_id, sos_lat, sos_lng)`, called from
`rakshak-sos-handler._create` in the **same invocation** that creates the
incident (not a separate async step):

1. Scan `rakshak-patrols` for every unit currently `Patrolling`.
2. For each, compute its *current* position via `compute_patrol_view` (not
   its route's static start point — a unit already mid-route is closer or
   farther than its nominal home position).
3. Sort by haversine distance to the SOS.
4. Attempt a **conditional** DynamoDB write
   (`ConditionExpression="status = Patrolling"`) transitioning the closest
   unit to `Responding`. If another concurrent request already claimed it
   (`ConditionalCheckFailedException`), move to the next-nearest and retry.
5. If every unit is busy, the incident is created with
   `assigned_patrol_id = null` and status stays `active` ("Awaiting
   Patrol") — the citizen app shows this state explicitly rather than
   silently failing.

This makes double-assignment structurally impossible without needing a
distributed lock: the conditional write is the lock.

## ETA engine

While `Responding`, `eta_seconds` comes directly from `lerp_toward`'s
`remaining_m / (speed_kmph * 1000/3600)` — recomputed fresh on every read,
so it counts down accurately even under clock skew or a slow client poll,
and jumps correctly if the assigned unit's position was itself mid-transit
when the SOS was raised.

## Return-to-route

`release_patrol(patrol_id)` (called on `resolved`/`cancelled`) transitions
a unit to `Returning`, anchored at wherever `compute_patrol_view` says it
currently is — not its route's start point, so there's no visual jump.
When `lerp_toward` reports `arrived=True` (in `compute_patrol_view`'s
`S_RETURN` branch), the view carries `_settle_to_patrolling=True`; the
calling handler then persists `settle_patrol_to_patrolling()`, which resets
`status=Patrolling` **and** `cycle_start_ts=now` — re-anchoring the unit to
"just started its loop" rather than leaving a stale `cycle_start_ts` that
would make it appear to teleport partway around the route.

`scripts/seed_demo_state.py`'s `clear_active()` (used to reset the demo
between runs) calls this same pair — `release_patrol()` then
`settle_patrol_to_patrolling()` — rather than hand-rolling a status update,
specifically to avoid the stale-`cycle_start_ts` position jump and to clear
the *real* divert/assignment attributes (`sos_lat`, `sos_lng`,
`divert_start_ts`, `divert_from_lat`, `divert_from_lng`) instead of a set
of legacy attribute names (`target_lat`, `target_lng`) that were never
actually written by the current handlers.

## Why compute-on-read instead of a scheduler

- **No missed-tick drift.** A scheduled job that fails to run for 90
  seconds leaves every position stale by 90 seconds; compute-on-read has no
  such failure mode — the next read is always correct.
- **No idle cost.** 20 units moving 24/7 would otherwise need a
  continuously running process; here, cost is proportional to actual reads.
- **Trivially consistent under concurrent reads.** Two clients polling
  `GET /patrols` a millisecond apart get the same position without needing
  to coordinate, because both derive it from the same stored anchor.
