# Demo Runbook

Exact commands to run the live demo end-to-end. The backend is already
deployed and live at `https://aksdwfbnn5.execute-api.ap-south-1.amazonaws.com`
— none of this requires a fresh deploy unless you're demoing from a clean
account (see `DEPLOYMENT.md`).

## 1. Pre-flight (once)

```bash
aws sso login --profile agent-toolkit
bash deploy/verify.sh                    # confirm the live API is healthy before the audience arrives
```

Expect `ALL CHECKS PASSED` — health, all 6 frozen-contract read routes,
performance budgets, ML tier (`source: s3-model`, not `baseline`), 44/44
zones real-model-scored, and a full SOS create→accept→status→resolve
lifecycle.

## 2. Reset demo state (optional, before a fresh run)

```bash
AWS_PROFILE=agent-toolkit python3 scripts/seed_demo_state.py --clear-active --apply
AWS_PROFILE=agent-toolkit python3 scripts/seed_demo_state.py --apply
```

First command purges any left-over live incidents from a previous run and
releases their patrols cleanly back to `Patrolling` (no stale position
jump — `PATROL_SIMULATION.md`). Second seeds 20 patrol units and ~9
resolved/cancelled history incidents so the dashboard timeline isn't
empty on open.

## 3. Launch all three apps

```bash
bash scripts/launch_demo.sh
```

Runs `flutter pub get`/`npm install` if needed, then launches
citizen-app, police-app, and the dashboard concurrently, logging to
`.demo-logs/`. Ctrl-C stops all three.

Manual alternative, one terminal each:

```bash
cd citizen-app && flutter run -d chrome
cd police-app  && flutter run -d chrome
cd dashboard   && npm run dev
```

## 4. Walkthrough script

1. **Dashboard**: open first, show the live heatmap
   (`GET /dashboard/heatmap`) — all 44 zones scored, colors driven by the
   real model. Point out the snapshot counts (patrols by status,
   incidents by status).
2. **Citizen app**: log in / open, show the current zone's live safety
   score (`GET /prediction/{zone}`). Trigger an SOS.
3. **Immediately switch to dashboard or police app**: the new incident
   appears in the live feed within one poll cycle, already showing an
   `assigned_patrol_id` and `eta_seconds` — auto-dispatch happened inside
   the same `POST /sos` call, not as a follow-up step.
4. **Police app**: accept the incident, mark reached, resolve. Watch the
   patrol's marker on the dashboard map move to the SOS location and back
   to its route as the status transitions — this is the same live
   `compute_patrol_view` the API returns, not a canned animation.
5. **Dashboard timeline**: the resolved incident now appears with its
   full event history (`created → assigned → en_route → reached →
   resolved`).

## 5. Talking points mapped to docs

| Moment | Doc to cite if asked |
|---|---|
| "How does auto-dispatch avoid double-assigning a patrol?" | `PATROL_SIMULATION.md` — conditional write |
| "Where does the risk score come from?" | `DATASET_CARD.md` + `ML_PIPELINE.md` |
| "Why not just call a hosted ML API?" | `CODE_CORTEX_AI_ML.md` |
| "What happens if the ML model is down?" | `ML_PIPELINE.md` — 3-tier resolver + circuit breaker |
| "Is this actually deployed, or a mockup?" | `AWS_RESOURCES.md` — live account, ID, resource inventory |
| "What's not production-ready yet?" | `SECURITY_MODEL.md` known gaps, honestly listed |

## 6. Troubleshooting

- **A route returns `404`/`500` unexpectedly**: `bash deploy/verify.sh` —
  re-run to isolate which route regressed, then
  `aws logs tail /aws/lambda/<fn> --profile agent-toolkit --since 10m`.
- **Patrol positions look frozen**: confirm the app is actually polling
  (`GET /dashboard/patrols` / `/patrols`) — positions are compute-on-read,
  so a paused poll shows a paused (not wrong) position.
- **Prediction source shows `"baseline"` instead of `"s3-model"`**: the
  circuit breaker has the S3-model tier marked failed for its 5-minute
  cooldown — check `GET /health` for `tier_status`, and CloudWatch logs
  for the original failure.
