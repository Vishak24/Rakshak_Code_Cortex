# AWS Architecture

Account `468704514492`, region `ap-south-1`. Live resource IDs, versions, and
counts are tracked separately in [`AWS_RESOURCES.md`](AWS_RESOURCES.md) (that
file is regenerated from the account; this one describes the shape, which
changes far less often).

## Component diagram

```
                              ┌───────────────────────────┐
  citizen-app / police-app /  │   API Gateway (HTTP API)  │
  dashboard  (HTTPS, JSON)    │   aksdwfbnn5 — $default   │
                        ─────▶│   native CORS, no auth     │
                              └─────────────┬──────────────┘
                                             │ AWS_PROXY, payload v2.0
                ┌────────────────────────────┼─────────────────────────────┐
                ▼                            ▼                             ▼
    rakshak-sos-handler          rakshak-patrol-handler          rakshak-dashboard
    256MB / 30s                  256MB / 30s                     1024MB / 30s, ML layer
    SOS lifecycle, auto-         20-unit compute-on-read           snapshot/timeline/heatmap/
    dispatch, police feed,       simulation, ETA, divert/return    prediction/health/version
    accept/status/resolve
                │                            │                             │
                └──────────────┬─────────────┴──────────────┬──────────────┘
                                ▼                            ▼
                          DynamoDB                 rakshak-test-inference
                    (PAY_PER_REQUEST)               1024MB/30s, ML layer
                                │                    POST /predict, batch
                                │                            │
                                │                            ▼
                                │              Lambda layer: numpy 2.1.3,
                                │              scipy 1.14.1, xgboost-cpu 3.2.0
                                │                            │
                                │                 ┌──────────┴──────────┐
                                │                 ▼                     ▼
                                │         SageMaker endpoint      S3 booster.json
                                │         (optional, env-gated,   (models/v2/booster.json,
                                │          tier 1 if present)      tier 2 — currently primary)
                                │                                        │
                                │                              tier 3: deterministic
                                │                              per-zone baseline
                                ▼
                rakshak-reports-handler, rakshak-night-monitor,
                rakshak-routing  (role creds, no embedded keys)
```

## Why HTTP API, not REST API

The frozen contract needs proxy integration, native CORS, and nothing else —
no request validators, no usage plans, no custom authorizers at this stage.
HTTP API gives that with lower latency and cost than REST API v1. If an
authorizer or WAF is added later (see [`SECURITY_MODEL.md`](SECURITY_MODEL.md)
known gaps), REST API or a Lambda authorizer on the HTTP API would need
evaluating then — not a blocker today.

## Why Lambda, not a container / EC2 backend

- **Traffic shape**: bursty (an SOS is a spike, not steady load); Lambda's
  per-invocation billing and instant horizontal scaling matches this better
  than a fixed-capacity server.
- **Operational surface**: no servers to patch, no ASG to size, no ALB to
  configure — the whole backend is 7 functions + API Gateway + DynamoDB.
- **Cold starts**: mitigated for the 4 contract-serving functions
  (`rakshak-sos-handler`, `rakshak-patrol-handler`, `rakshak-dashboard`,
  `rakshak-test-inference`) with a 5-minute EventBridge keep-warm rule (see
  [`OBSERVABILITY.md`](OBSERVABILITY.md)).

## Why DynamoDB, not RDS

Every access pattern in this app is a point lookup by ID or a scan/query
filtered by status — no joins, no multi-table transactions. `PAY_PER_REQUEST`
billing matches the demo's spiky, low-baseline traffic without provisioning a
minimum capacity. The one query that used to require a full table scan
(active SOS incidents) now has a purpose-built GSI —
[`DATABASE_SCHEMA.md`](DATABASE_SCHEMA.md).

## Why a Lambda-local ML model, not API-only inference

See [`CODE_CORTEX_AI_ML.md`](CODE_CORTEX_AI_ML.md) for the full judge-facing
answer. Short version: a SageMaker real-time endpoint is a second billed,
always-on compute resource for a workload that a stateless, S3-cached
XGBoost booster serves in well under 300ms from inside the same Lambda that
already needs to run — with SageMaker still available as an optional tier 1
if the deployment ever needs an isolated, independently-scaled inference
fleet (env-gated, zero code change to switch back on).

## Request path: SOS creation to resolution

1. Citizen app → `POST /sos` → `rakshak-sos-handler._create`.
2. Handler validates the payload (Chennai bounding box, required fields),
   writes the incident row, and in the **same invocation** calls
   `rakshak_common.assign_nearest_patrol` — a conditional DynamoDB write
   that assigns the nearest `Patrolling` unit or the next-nearest on
   contention, never double-assigning.
3. Police app polls `GET /incidents/active` → same Lambda, `_active`.
4. Officer `PATCH /incident/{id}/status` transitions dispatched → reached →
   resolved; each transition updates both the incident and patrol rows and
   appends a timeline event.
5. Dashboard polls `GET /dashboard/snapshot` / `/heatmap` independently — no
   coupling to the SOS lifecycle beyond reading the same tables.

Full route list: [`API_REFERENCE.md`](API_REFERENCE.md). Full patrol state
machine: [`PATROL_SIMULATION.md`](PATROL_SIMULATION.md).

## IAM

One shared execution role, `rakshak-lambda-role`, used by every Lambda:

- `AWSLambdaBasicExecutionRole` (managed) — CloudWatch Logs
- `AmazonS3ReadOnlyAccess` (managed) — read the ML model/layer artifacts
- `RakshakDynamoDBAccess` (inline) — CRUD scoped to the `rakshak-*` tables
- `SageMakerInvokePolicy` (inline) — `sagemaker:InvokeEndpoint` on
  `rakshak-risk-endpoint` only

No Lambda has embedded IAM access keys in its environment — confirmed via
`get-function-configuration` on every managed function. See
[`SECURITY_MODEL.md`](SECURITY_MODEL.md).

## What this architecture deliberately does not include (yet)

- No API authorizer — every route is public. Acceptable for a hackathon
  demo backed by a Chennai-only bounding-box validator; not acceptable
  as-is for a real deployment. Tracked in `SECURITY_MODEL.md`.
- No SNS/alerting on the 7 CloudWatch error alarms — they exist and are
  `OK`, but nothing pages anyone yet.
- No VPC — none of the current access patterns need one (no RDS, no
  internal-only services).
