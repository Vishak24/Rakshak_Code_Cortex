# Rakshak — AWS Resources

**Enumerated:** 2026-09-18 (updated after the Code_Cortex migration + sos-feed
merge pass) · **Account:** `468704514492` · **Region:** `ap-south-1` ·
**Profile:** `agent-toolkit`

This is the live account state as of the deploy below. Re-generate by running
the enumeration commands in `deploy/deploy.py --dry-run` output, or the raw
`aws apigatewayv2 get-routes/get-integrations`, `aws lambda list-functions`,
`aws dynamodb list-tables`, `aws s3 ls`, `aws sagemaker list-*` calls this was
built from.

## API Gateway

| | |
|---|---|
| API | `aksdwfbnn5` — `rakshak-api`, HTTP API, stage `$default` (auto-deploy) |
| Base URL | `https://aksdwfbnn5.execute-api.ap-south-1.amazonaws.com` |
| CORS | Native API-level CORS: `AllowOrigins: *`, `AllowMethods: GET,POST,PATCH,OPTIONS`, `AllowHeaders: content-type,authorization,x-amz-date,x-api-key`, `MaxAge: 300` |
| Routes | 37 (14 frozen-contract + 23 legacy/extension aliases — see `deploy/routes.py`) |

## Lambda functions

`rakshak-sos-feed` was merged into `rakshak-sos-handler` this pass (same
shared module, no cross-Lambda dependency) — its 6 routes were repointed to
`rakshak-sos-handler`'s integration (`im4k71v`) via `update-route`, verified
green end-to-end, then its own routes/integration/function were retired.
`rakshak-score-refresh` was retired the same way: its one caller
(`useRiskData.js` `POST /score/refresh`) no longer exists in the current
dashboard, which now polls `GET /heatmap/live` instead.

**The `rakshak-sos-feed` and `rakshak-score-refresh` Lambda functions,
routes, and integrations still physically exist in the account** — deleting
them requires an approval this migration pass didn't have. They are fully
orphaned (no route in `deploy/routes.py` points at them, verified) and
serve no live traffic. Delete manually or grant the approval and re-run the
one-off retirement script used this pass (see `DEPLOYMENT.md` "Retiring
sos-feed / score-refresh").

| Function | Managed by deploy.py | Memory/Timeout | Layer | Role |
|---|---|---|---|---|
| `rakshak-sos-handler` | ✅ (now includes merged sos-feed routes) | 256MB/30s | — | `rakshak-lambda-role` |
| `rakshak-patrol-handler` | ✅ | 256MB/30s | — | `rakshak-lambda-role` |
| `rakshak-reports-handler` | ✅ | 256MB/30s | — | `rakshak-lambda-role` |
| `rakshak-test-inference` | ✅ | 1024MB/30s | `rakshak-ml-layer:9` | `rakshak-lambda-role` |
| `rakshak-dashboard` | ✅ | 1024MB/30s | `rakshak-ml-layer:9` | `rakshak-lambda-role` |
| `rakshak-night-monitor` | ✅ (added to build_zips.sh this pass) | 256MB/30s | — | `rakshak-lambda-role` |
| `rakshak-routing` | ✅ (added to build_zips.sh this pass) | 256MB/30s | — | `rakshak-lambda-role` |
| `rakshak-sos-feed` | ⚠️ orphaned — retired, pending deletion (see above) | 256MB/30s | — | `rakshak-lambda-role` |
| `rakshak-score-refresh` | ⚠️ orphaned — retired, pending deletion (see above) | 512MB/30s | `rakshak-ml-layer:9` | `rakshak-lambda-role` |
| `rakshak-scan-inference` | no — orphaned (see `lambdas/_legacy/README.md`) | 256MB/30s | old `rakshak-ml-layer:7` | `rakshak-lambda-role` |
| `rakshak-sos-dispatch` | no — orphaned, no route | 256MB/30s | — | `rakshak-lambda-role` |
| `rakshak-location-update` | no — orphaned, no route, no log group (never invoked) | 256MB/30s | — | `rakshak-lambda-role` |

All Lambdas: Python 3.12, `x86_64`, handler `lambda_function.lambda_handler`. No embedded IAM
access keys found on any function's environment (confirmed via `get-function-configuration`).

## Warm-up (EventBridge)

| Rule | Schedule | Targets |
|---|---|---|
| `rakshak-warmup` | `rate(5 minutes)` | `rakshak-sos-handler`, `rakshak-patrol-handler`, `rakshak-dashboard`, `rakshak-test-inference` — each invoked with `{"warm": true}`, which every target's handler short-circuits on before any routing/DynamoDB work. |

## Lambda layers

| Layer | Version deployed | Contents |
|---|---|---|
| `rakshak-ml-layer` | **9** (attached to test-inference/dashboard/score-refresh) | numpy 2.1.3, scipy 1.14.1, xgboost-cpu 3.2.0 — py3.12, x86_64, ~177MB unzipped / ~54MB zipped |
| `rakshak-ml-layer` | 7 (old, still attached to `rakshak-scan-inference` only) | numpy, pandas, scipy, sklearn, joblib — **no xgboost** |
| `rakshak-ml-layer` | 8 (published then superseded) | same as v9 minus `numpy.f2py` — **broken**, deleting f2py breaks numpy's own import. Not attached to anything; kept in version history as a warning, do not reuse. |
| `rakshak-deps` | 1–5 (unused by any current function) | not inspected — no function references it after this deploy |

## DynamoDB

| Table | Keys | GSIs | Items (2026-09-18) | Managed |
|---|---|---|---|---|
| `rakshak-sos-alerts` | PK `sos_id` | **`status-created_at-index`** (PK `status`, SK `created_at`) — added this pass | 9 (history) | ✅ |
| `rakshak-patrols` | PK `patrol_id` | — | 20 | ✅ |
| `rakshak-incidents` | PK `incident_id`, SK `created_at` | — | 9 (citizen reports, not SOS incidents — naming trap) | ✅ |
| `rakshak-zones` | PK `pincode` | — | 0 (unused) | ✅ |
| `rakshak-users` | PK `user_id` | — | ~8 (citizen ping heartbeats via `rakshak-night-monitor`) | ✅ |
| `patrol_vehicles` | PK `vehicle_id` | — | 3 | legacy, unmanaged |
| `sos_alerts` | PK `alert_id`, SK `timestamp` | — | 3 | legacy, unmanaged |
| `user_locations` | PK `user_id`, SK `timestamp` | — | 0 | legacy, unmanaged |

## S3

| Bucket | Relevant contents |
|---|---|
| `rakshak-models-vishalganesan` | `rakshak_chennai_model_v2.pkl`, `label_encoder_{area,neighborhood}_v2.pkl`, `data/chennai_sos_enhanced_data_v2.csv`, `sagemaker/model-v2-20260904.tar.gz`, **`models/v2/booster.json`** (added this pass — standalone XGBoost booster, source of the local inference tier), `layers/rakshak-ml-layer-*.zip` (added this pass) |
| `rakshak-app`, `rakshak-frontend` | Static Flutter web hosting — unrelated to the backend, not touched |
| `sagemaker-ap-south-1-468704514492`, `sagemaker-studio-*` | SageMaker default buckets, not inspected |

## IAM

| Role | Attached policies | Notes |
|---|---|---|
| `rakshak-lambda-role` | `AWSLambdaBasicExecutionRole`, `AmazonS3ReadOnlyAccess` (managed) + `RakshakDynamoDBAccess` (inline: full CRUD on `rakshak-*` tables + the 3 legacy tables) + `SageMakerInvokePolicy` (inline: `sagemaker:InvokeEndpoint` on `rakshak-risk-endpoint`) | Shared by every Lambda in this account |
| `rakshak-sagemaker-role` | `AmazonS3ReadOnlyAccess`, `AmazonSageMakerFullAccess` (managed) + `ECRAccessPolicy` (inline) | SageMaker execution role, used by `deploy/sagemaker/deploy.sh` |

No standalone IAM access keys found attached to any Lambda's environment. An IAM *user* key
(`AKIA…7YPR`, referenced in prior docs as deactivated-but-not-deleted) was not re-verified this
pass — rotate/delete it if it still exists (`aws iam list-access-keys` on whichever user owns it).

## SageMaker

| Resource | State |
|---|---|
| Endpoint `rakshak-risk-endpoint` | **Does not exist** (`list-endpoints` returns empty) — this is why every prediction fell back to `baseline` before this deploy |
| Model `rakshak-risk-model-v2` | exists |
| Endpoint config `rakshak-risk-endpoint-config-v2` | exists |

Recreating the endpoint is optional — `predict_batch()` treats SageMaker as tier 1 only when
`SAGEMAKER_ENDPOINT` is non-empty (it currently is, `rakshak-risk-endpoint`, which fails fast
and falls to tier 2). To restore it: `bash deploy/sagemaker/deploy.sh` (reproducible, validated
script, unchanged by this pass). Recommend Serverless Inference over the previous
`ml.m5.large` real-time endpoint if restored, to avoid idle cost — the local tier already serves
every zone in under a second, so a real-time instance is no longer load-bearing for the demo.

## CloudWatch

- Log retention: **14 days** set on every reachable `/aws/lambda/rakshak-*` log group
  (`rakshak-location-update` has never been invoked so no log group exists yet).
- Alarms: `Errors >= 1 / 5min` alarms, one per function in `MANAGED_FUNCTIONS`
  (`rakshak-<fn>-errors`) — 7 functions as of this pass (added
  `rakshak-night-monitor-errors` and `rakshak-routing-errors` this session), all `OK`.
  **No SNS action attached** — nothing pages anyone yet. Follow-up: create
  an SNS topic and subscribe an email/Slack webhook, then `put-metric-alarm --alarm-actions
  <topic-arn>` on each.
