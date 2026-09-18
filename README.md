<p align="center">
  <img alt="status" src="https://img.shields.io/badge/status-production-brightgreen">
  <img alt="region" src="https://img.shields.io/badge/AWS-ap--south--1-orange">
  <img alt="tests" src="https://img.shields.io/badge/tests-30%2F30_passing-brightgreen">
  <img alt="ml" src="https://img.shields.io/badge/inference-XGBoost_3.2-blue">
  <img alt="license" src="https://img.shields.io/badge/license-MIT-lightgrey">
</p>

# Rakshak

**A serverless women's-safety platform for Chennai: real-time SOS dispatch, a
simulated 20-unit patrol fleet, ML-driven zone risk scoring, and a live
command dashboard — built entirely on AWS Lambda, API Gateway, and DynamoDB.**

Three apps share one backend contract: a **citizen app** (Flutter) for
raising an SOS and seeing nearby safety scores, a **police app** (Flutter)
for the live incident feed and patrol status, and a **command dashboard**
(React/Vite) for city-wide analytics and the risk heatmap.

## Why Rakshak

Most SOS apps stop at "notify someone." Rakshak closes the loop:

| | Typical SOS app | Rakshak |
|---|---|---|
| On alert | Push a notification / SMS | Auto-assigns the **nearest available patrol** in the same call that creates the incident |
| Patrol visibility | None | 20 simulated units with live, compute-on-read positions, ETA, and full divert/return state machine |
| Risk awareness | None, or a static heatmap | Per-zone ML risk score (XGBoost) served in under 200ms, covering all 44 serviced Chennai pincodes |
| Command view | None | Live dashboard: snapshot, timeline, heatmap, incident lifecycle — all from one contract |
| ML availability | Single point of failure | 3-tier resolver (SageMaker → S3 Lambda-local model → deterministic baseline) with a circuit breaker — `/predict` never 500s |

See [`docs/USP_AND_INNOVATION.md`](docs/USP_AND_INNOVATION.md) for the full,
factual comparison.

## Architecture

```
                        ┌─────────────────────────┐
citizen-app  ───┐       │   API Gateway (HTTP)    │
police-app   ───┼──────▶│   aksdwfbnn5, $default  │
dashboard    ───┘       └────────────┬────────────┘
                                      │  AWS_PROXY, 37 routes
              ┌───────────────────────┼────────────────────────┐
              ▼                       ▼                         ▼
   rakshak-sos-handler      rakshak-patrol-handler       rakshak-dashboard
   (SOS lifecycle,          (20-unit sim, ETA,           (snapshot/timeline/
    police feed, dispatch)   divert/return)               heatmap/prediction)
              │                       │                         │
              └───────────┬───────────┴────────────┬────────────┘
                           ▼                        ▼
                     DynamoDB                rakshak-test-inference
              (sos-alerts, patrols,          (POST /predict, batch
               incidents, users,              ML inference)
               zones + GSI)                          │
                                                      ▼
                                     Lambda layer: numpy + scipy + xgboost-cpu
                                     booster.json (S3) ── SageMaker (optional) ── baseline
```

Full detail: [`docs/AWS_ARCHITECTURE.md`](docs/AWS_ARCHITECTURE.md).

## ML pipeline

Zone risk (Low / Medium / High) is scored by an XGBoost model trained on a
**synthetically generated, geographically and temporally engineered Chennai
safety dataset** (44 real pincodes, 20,800 rows) — not a downloaded public
dataset. See:

- [`docs/DATASET_CARD.md`](docs/DATASET_CARD.md) — what the dataset is, how it was built, honest limitations
- [`docs/FEATURE_ENGINEERING.md`](docs/FEATURE_ENGINEERING.md) — geographic, temporal, patrol-coverage, hotspot engineering
- [`docs/ML_PIPELINE.md`](docs/ML_PIPELINE.md) — training, evaluation, inference, the 3-tier resolver
- [`docs/CODE_CORTEX_AI_ML.md`](docs/CODE_CORTEX_AI_ML.md) — judge-facing Q&A on model choice, Lambda inference, scalability

## Demo flow

1. Citizen opens the app, sees the live safety score for their zone (`GET /prediction/{zone}`).
2. Citizen raises an SOS (`POST /sos`) → nearest free patrol is auto-assigned in the same call.
3. Police app shows the incident in the live feed (`GET /incidents/active`), accepts, marks reached, resolves.
4. Dashboard shows the incident, the responding patrol's live position, and the city risk heatmap updating throughout.

Full walkthrough with exact commands: [`docs/DEMO_RUNBOOK.md`](docs/DEMO_RUNBOOK.md).

## Repository layout

```
Code_Cortex/
├── backend/            Lambda source (7 managed functions + 3 orphaned/legacy, documented)
│   ├── lambdas/         one dir per function + _shared/rakshak_common.py (vendored into every zip)
│   └── build/            build_zips.sh — reproducible, byte-identical zip builds
├── deploy/             deploy.py (idempotent infra tool), routes.py (route→function map), verify.sh
├── tests/               30 pytest cases, run with no AWS (in-memory DynamoDB double)
├── ml/                  synthetic dataset generator, training script, dataset, metadata
├── citizen-app/         Flutter — SOS, live safety score, incident tracking
├── police-app/          Flutter — incident feed, accept/status/resolve, patrol map
├── dashboard/            React/Vite — snapshot, timeline, heatmap, analytics
├── assets/              backend-canonical GeoJSON + 20-unit patrol route set
├── scripts/             seed_demo_state.py, launch_demo.sh
└── docs/                architecture, API, ML, security, demo, release docs (this list continues below)
```

## Setup

```bash
git clone <this-repo> && cd Code_Cortex

# Backend
python3 -m pip install -r requirements-dev.txt
make test                    # 30 pytest cases, no AWS needed

# Frontends
cd citizen-app && flutter pub get && cd ..
cd police-app  && flutter pub get && cd ..
cd dashboard   && npm ci && cd ..
```

## Deployment

```bash
aws sso login --profile agent-toolkit          # or: aws login --profile agent-toolkit
make deploy-dry                                 # idempotent dry-run — see exactly what would change
make deploy                                      # ships code, layer (if requirements changed), routes
make verify                                      # live smoke test against the deployed API
```

Nothing here creates infrastructure from empty — every step is
check-first-then-create. See [`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md) for
the full idempotency contract and [`docs/AWS_RESOURCES.md`](docs/AWS_RESOURCES.md)
for the current live resource inventory.

## API reference

37 routes (14 frozen-contract + 23 legacy/compatibility aliases). Full list
with request/response shapes: [`docs/API_REFERENCE.md`](docs/API_REFERENCE.md).
Sample payloads for every route: [`docs/api-samples/`](docs/api-samples/).

## Documentation index

| Doc | Covers |
|---|---|
| [ARCHITECTURE_AUDIT.md](docs/ARCHITECTURE_AUDIT.md) | Original 14-section principal-architect audit this build implements |
| [AWS_ARCHITECTURE.md](docs/AWS_ARCHITECTURE.md) | Full AWS component diagram and request path |
| [AWS_RESOURCES.md](docs/AWS_RESOURCES.md) | Live resource inventory (account, API ID, table/function/layer versions) |
| [DEPLOYMENT.md](docs/DEPLOYMENT.md) | Idempotent deploy tool, layer rebuild policy, rollback |
| [API_REFERENCE.md](docs/API_REFERENCE.md) | Every route, method, request/response |
| [DATABASE_SCHEMA.md](docs/DATABASE_SCHEMA.md) | DynamoDB tables, keys, GSI, item shapes |
| [PATROL_SIMULATION.md](docs/PATROL_SIMULATION.md) | Compute-on-read position engine, ETA, divert/return state machine |
| [DATASET_CARD.md](docs/DATASET_CARD.md) | Dataset provenance, honest scope and limitations |
| [FEATURE_ENGINEERING.md](docs/FEATURE_ENGINEERING.md) | Geographic, temporal, hotspot, patrol-coverage feature design |
| [ML_PIPELINE.md](docs/ML_PIPELINE.md) | Training, evaluation, the 3-tier inference resolver |
| [CODE_CORTEX_AI_ML.md](docs/CODE_CORTEX_AI_ML.md) | Judge Q&A: model choice, Lambda vs. API-only ML, scalability |
| [OBSERVABILITY.md](docs/OBSERVABILITY.md) | Logging, alarms, warm-up, what's not yet wired |
| [SECURITY_MODEL.md](docs/SECURITY_MODEL.md) | IAM, no embedded keys, CORS, input validation, known gaps |
| [USP_AND_INNOVATION.md](docs/USP_AND_INNOVATION.md) | Factual comparison against typical SOS apps |
| [DEMO_RUNBOOK.md](docs/DEMO_RUNBOOK.md) | Exact commands to run the live demo end-to-end |
| [GITHUB_RELEASE_CHECKLIST.md](docs/GITHUB_RELEASE_CHECKLIST.md) | What's done, what's left before pushing |

## Screenshots

_Add screenshots to `docs/screenshots/` and reference them here before publishing:_

| Citizen app | Police app | Dashboard |
|---|---|---|
| `docs/screenshots/citizen-home.png` | `docs/screenshots/police-feed.png` | `docs/screenshots/dashboard-heatmap.png` |

## Team

Built for Code Cortex 3.0 / AWS First Commit Hackathon.
_Add team member names and roles here before publishing._

## License

[MIT](LICENSE)
