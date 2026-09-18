# Test Report

Generated from live output during the `RAKSHAK ALL` → `Code_Cortex`
production migration, 2026-09-18. Every result below is copied from an
actual command run this session — nothing here is projected.

## Summary

| Suite | Result |
|---|---|
| Backend unit tests (pytest) | **30/30 passed** |
| Deploy idempotency (dry-run) | **PASS** — 0 mutating actions on a clean dry-run |
| Infrastructure / API smoke test (`verify.sh`) | **ALL CHECKS PASSED** (19/19 checks) |
| ML inference (44-zone prediction) | **PASS** — 44/44 zones real-model-scored |
| Performance | **PASS** — all 3 budgeted routes within target, best-of-3 |
| Patrol simulation | **PASS** (covered by pytest + live `/dashboard/patrols`) |
| Incident lifecycle | **PASS** — full create→accept→status→resolve verified live |
| citizen-app static analysis | **PASS** — 0 errors (55 style-only `info` lints) |
| police-app static analysis | **PASS** — 0 errors (59 style-only `info` lints) |
| dashboard build | **PASS** — `vite build` succeeded, 545ms |

## 1. Backend unit tests

```
$ python3 -m pytest tests -v
============================= test session starts ==============================
collected 30 items

tests/test_backend.py::test_route_interpolation_wraps_and_is_continuous PASSED
tests/test_backend.py::test_route_progress_is_monotonic_within_a_segment PASSED
tests/test_backend.py::test_lerp_toward_clamps_at_target PASSED
tests/test_backend.py::test_to_from_ddb_roundtrip PASSED
tests/test_backend.py::test_zone_for_point_returns_a_pincode PASSED
tests/test_backend.py::test_predict_safety_baseline_shape PASSED
tests/test_backend.py::test_get_patrols_returns_live_positions PASSED
tests/test_backend.py::test_sos_live_accepts_float_gps_and_assigns_patrol PASSED
tests/test_backend.py::test_sos_live_with_null_latitude_key_still_assigns PASSED
tests/test_backend.py::test_assignment_contention_falls_through_to_next_nearest PASSED
tests/test_backend.py::test_one_patrol_one_sos_and_feed_visibility PASSED
tests/test_backend.py::test_reached_then_resolved_releases_patrol_and_leaves_feed PASSED
tests/test_backend.py::test_returning_patrol_settles_back_to_patrolling PASSED
tests/test_backend.py::test_path_param_vs_rawpath_fallback_both_resolve PASSED
tests/test_backend.py::test_dispatch_and_resolve_empty_id_is_400 PASSED
tests/test_backend.py::test_cancel_releases_patrol PASSED
tests/test_backend.py::test_reports_submit_list_moderate PASSED
tests/test_backend.py::test_predict_endpoint_never_500s_and_returns_0_100 PASSED
tests/test_backend.py::test_dashboard_snapshot_timeline_heatmap_prediction PASSED
tests/test_backend.py::test_dashboard_prediction_missing_zone_is_400 PASSED
tests/test_backend.py::test_frozen_contract_post_sos_alias_matches_sos_live PASSED
tests/test_backend.py::test_frozen_contract_get_incident_by_id PASSED
tests/test_backend.py::test_frozen_contract_get_incident_eta PASSED
tests/test_backend.py::test_frozen_contract_incidents_active_alias PASSED
tests/test_backend.py::test_frozen_contract_accept_is_additive_and_keeps_status PASSED
tests/test_backend.py::test_frozen_contract_status_and_resolve_aliases PASSED
tests/test_backend.py::test_frozen_contract_dashboard_patrols_heatmap_prediction_health_version PASSED
tests/test_backend.py::test_patrol_status_whitelist_rejects_invalid PASSED
tests/test_backend.py::test_predict_batch_matches_predict_safety_and_orders_results PASSED
tests/test_backend.py::test_circuit_breaker_opens_after_failure_and_reports_via_tier_status PASSED

============================== 30 passed in 0.17s ==============================
```

Runs with no AWS credentials (`tests/conftest.py`'s in-memory DynamoDB
double). Covers: route interpolation math, GPS Decimal handling,
auto-assignment + contention fallthrough, full SOS lifecycle, patrol
return-to-route settling, frozen-contract route aliasing, input validation
(400s), reports moderation, ML inference (baseline + batch + circuit
breaker), dashboard aggregation.

## 2. Deploy idempotency

```
$ AWS_PROFILE=agent-toolkit python3 deploy/deploy.py --dry-run
Rakshak-SIH deploy — profile=agent-toolkit region=ap-south-1 account=468704514492 api=aksdwfbnn5 [DRY RUN]
  identity ok — arn:aws:iam::468704514492:root
[build] pytest (must pass before anything ships)
[build] build_zips.sh
[layer] unchanged (requirements hash 563878c2b272e161) — skip rebuild
[lambda] rakshak-sos-handler code unchanged — skip update-function-code
[lambda] rakshak-patrol-handler code unchanged — skip update-function-code
[lambda] rakshak-reports-handler code unchanged — skip update-function-code
[lambda] rakshak-test-inference code unchanged — skip update-function-code
[lambda] rakshak-dashboard code unchanged — skip update-function-code
[lambda] rakshak-night-monitor code unchanged — skip update-function-code
[lambda] rakshak-routing code unchanged — skip update-function-code
[apigw] 37 existing routes, 10 existing integrations

deploy.py done.
```

**Zero mutating actions planned** — every managed function reports "code
unchanged," the layer is unchanged, and every route/integration already
exists. This confirms the migration from `RAKSHAK ALL` to `Code_Cortex`
(path fixes, the sos-feed merge, the warm-up guards) is fully reconciled
with what's actually live, and that re-running the deploy tool is safe and
free of side effects.

## 3. Live API smoke test (`deploy/verify.sh`)

```
== Rakshak-SIH verify == https://aksdwfbnn5.execute-api.ap-south-1.amazonaws.com

-- System --
  PASS  GET /health (200)
  PASS  GET /version (200)

-- Frozen contract: read routes --
  PASS  GET /dashboard/snapshot (200)
  PASS  GET /dashboard/patrols (200)
  PASS  GET /dashboard/timeline (200)
  PASS  GET /dashboard/heatmap (200)
  PASS  GET /prediction/{zone} (200)
  PASS  GET /incidents/active (200)

-- Performance (warm) --
  PASS  dashboard/snapshot 142ms <= 500ms (best of 3)
  PASS  prediction/{zone} 120ms <= 300ms (best of 3)
  PASS  dashboard/patrols 129ms <= 300ms (best of 3)

-- ML tier --
  PASS  prediction source=s3-model (real model, not baseline)

-- Heatmap: 44 zones, all real-model-scored --
  zone_count=44 real_model=44
  PASS  44/44 zones, all real-model-scored

-- Full SOS lifecycle (frozen-contract paths; writes + cleans up one row) --
  PASS  POST /sos -> SOS-37EDFFD4
  PASS  GET /incident/{id} (200)
  PASS  GET /incident/{id}/eta (200)
  PASS  PATCH /incident/{id}/accept (200)
  PASS  PATCH /incident/{id}/status (200)
  PASS  PATCH /incident/{id}/resolve (200)

ALL CHECKS PASSED
```

This run exercises the **merged** `rakshak-sos-handler` — `/incidents/active`,
`/incident/{id}/accept`, `/incident/{id}/status`, and
`/incident/{id}/resolve` are all served by it after this session's
route-repointing migration (previously `rakshak-sos-feed`); all pass.

## 4. Frontend build gates

```
$ cd citizen-app && flutter analyze lib
55 issues found. (ran in 1.4s)   # all `info` — 0 errors
                                   # (initial run found 15 errors from a rsync
                                   #  exclude pattern that also matched nested
                                   #  lib/features/*/data/ dirs; fixed by
                                   #  anchoring the exclude to top-level /data
                                   #  only — re-run above is the corrected state)

$ cd police-app && flutter analyze lib
59 issues found. (ran in 1.7s)   # all `info` — 0 errors

$ cd dashboard && npm ci && npm run build
✓ 60 modules transformed.
✓ built in 545ms
```

## 5. Not covered by this report

- **Load/stress testing** — not performed; current verified load is the
  smoke test's sequential single-request checks, not concurrent traffic.
- **End-to-end UI testing** (Flutter/Playwright integration tests present
  in the source archive) — not re-run this pass; static analysis + build
  success were used as the frontend gate, consistent with `AGENTS`/task
  scope ("do not modify frontend UI beyond API configuration").
- **Deletion of the two orphaned Lambda resources** (`rakshak-sos-feed`,
  `rakshak-score-refresh`) — blocked by a permission gate on destructive
  AWS actions; see `docs/AWS_RESOURCES.md` and `docs/DEPLOYMENT.md`.
