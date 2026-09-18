# Observability

## Logging

Every Lambda logs to `/aws/lambda/<function-name>` via the standard Lambda
runtime logger (`print()` statements in exception handlers, e.g.
`predict_batch`'s tier-failure logs). Retention: **14 days**, set on every
reachable log group by `deploy/deploy.py`'s `ensure_observability`
(idempotent — skips if already 14 days).

```bash
aws logs tail /aws/lambda/rakshak-sos-handler --profile agent-toolkit --follow
```

## Alarms

One `Errors >= 1 / 5min` CloudWatch alarm per managed function
(`rakshak-<fn>-errors`), created by `ensure_observability`. **No SNS action
is attached** — the alarms exist and are inspectable
(`aws cloudwatch describe-alarms --profile agent-toolkit`), but nothing
pages anyone on trip. This is a known, stated gap, not an oversight:

```bash
aws sns create-topic --name rakshak-alerts --profile agent-toolkit
aws sns subscribe --topic-arn <arn> --protocol email --notification-endpoint you@example.com --profile agent-toolkit
aws cloudwatch put-metric-alarm --alarm-name rakshak-sos-handler-errors \
  --alarm-actions <topic-arn> ...   # repeat per function, or extend ensure_observability
```

## Health and version endpoints

- `GET /health` — liveness, plus (via `rakshak_common.tier_status()`) the
  current circuit-breaker state of the ML resolver's tiers — the fastest
  way to see whether SageMaker/S3-model/baseline is currently serving
  predictions without triggering one.
- `GET /version` — `{version, generated_at}`, `version` from the
  `BUILD_VERSION` environment variable if set, else the code constant
  (currently `1.0.0` in `rakshak-dashboard/lambda_function.py`).

## Warm-up

An EventBridge rule, `rakshak-warmup`, fires `rate(5 minutes)` against the
4 contract-serving functions (`rakshak-sos-handler`, `rakshak-patrol-handler`,
`rakshak-dashboard`, `rakshak-test-inference`) with payload `{"warm": true}`.
Every one of those handlers checks for this key **before** any routing,
DynamoDB, or model work:

```python
if isinstance(event, dict) and event.get("warm"):
    return {"warm": True}
```

This matters specifically for `rakshak-patrol-handler`: its router falls
through to `_list_patrols()` (a full 20-row scan + on-read settle) on any
unmatched `GET`, so an unguarded warm ping would have silently triggered a
full patrol computation every 5 minutes — the guard makes the keep-warm
ping genuinely free.

## Performance budget (verified, `deploy/verify.sh`)

| Route | Budget | Observed (best of 3, warm) |
|---|---|---|
| `/dashboard/snapshot` | 500ms | ~150ms |
| `/prediction/{zone}` | 300ms | ~125–140ms |
| `/dashboard/patrols` | 300ms | ~130–135ms |

Single-sample checks were found to false-fail on network jitter to
`ap-south-1` during this project's development (one observed 488ms sample
against a true ~150ms typical latency); `verify.sh` now warms the route
once, then reports the best of 3 real samples.

## What's not wired up (stated honestly)

- No alerting destination on the error alarms (above).
- No distributed tracing (X-Ray) — request paths are short enough (one
  Lambda, one or two DynamoDB calls) that this hasn't been a diagnosis
  gap yet; would matter more if the SageMaker tier's network hop becomes
  load-bearing.
- No dashboard-of-dashboards (CloudWatch Dashboard resource) — the
  individual alarms and log groups are the current observability surface.
