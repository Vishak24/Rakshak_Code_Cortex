# AI/ML — Judge Q&A

Direct answers to the questions a technical judge is most likely to ask,
cross-referenced to the detailed docs.

## How is the dataset actually used?

It isn't "used" in the sense of being a downloaded, pre-existing dataset —
it's **generated** by two scripts in `ml/`
(`generate_chennai_synthetic_datav2.py`, `Finaldataset.py`) that encode the
team's own domain assumptions about how Chennai safety signals should look,
over real Chennai geography. The model is trained on this generated data.
Full provenance, including exactly what is and isn't synthetic, and honest
limitations: [`DATASET_CARD.md`](DATASET_CARD.md).

## What feature engineering was actually done?

Four categories, each a deliberate encoding decision rather than a raw
data field: geographic (real coordinates + a latitude-band risk proxy),
temporal (hour/day/night/rush-hour flags with a non-uniform time
distribution), patrol-coverage/response (reporting delay, response time —
called out in the team's own prior submission as the genuine novel
insight, not a dataset artifact), and hotspot (rolling 7d/30d signal
density with a recency ratio). Full breakdown with the exact formulas:
[`FEATURE_ENGINEERING.md`](FEATURE_ENGINEERING.md).

## Why XGBoost, and not a neural net / a simpler model?

- **Tabular, structured, 17-feature input** — this is exactly XGBoost's
  strong case; a neural net buys nothing here and costs more to train,
  tune, and explain.
- **Feature importance is directly inspectable** — `model.feature_importances_`
  gave a fast, honest check that the model was learning the intended
  signal (see `ML_PIPELINE.md`'s evaluation section for what that check
  actually revealed about the label's construction).
- **Multi-class native support** (`multi:softprob`, 3 classes) without a
  one-vs-rest wrapper.
- **A `Booster` exports to a single, dependency-light `booster.json`** — no
  pickle, no sklearn version coupling, loadable in a Lambda layer with just
  `xgboost-cpu` (a ~5.6MB wheel) instead of the full `xgboost` package or
  a full sklearn stack. This directly enabled the Lambda-local inference
  tier below.
- **CPU inference in well under 300ms** for a 44-row batch, inside a
  1024MB Lambda with no GPU — logistic regression would be simpler still
  but loses the non-linear interaction the label formula actually encodes
  (e.g. `is_night AND signal_count_last_7d > 12` isn't linearly separable
  from the individual features alone).

## Why run inference in Lambda instead of calling a hosted ML API?

Both options were built and are live simultaneously — this isn't a
theoretical choice:

- **SageMaker endpoint (`rakshak-risk-endpoint`)**: exists as tier 1 in the
  resolver, env-gated (`SAGEMAKER_ENDPOINT`), currently not provisioned
  (no idle real-time instance cost while the local tier fully covers the
  demo — see `AWS_RESOURCES.md`). Trivial to bring back
  (`deploy/sagemaker/deploy.sh`) if the deployment ever needs an
  isolated, independently-scaled inference fleet — e.g. a much larger
  model, or inference workloads shared across services beyond this Lambda.
- **Lambda-local (`rakshak-test-inference`, `rakshak-dashboard`)**: the
  model (a few MB `booster.json`) is cached in `/tmp` and as a module-level
  global on a warm container, so *steady-state* inference cost is a numpy
  matrix multiply inside a Lambda that's already running — no network hop
  to a second service, no second thing to keep warm, no per-endpoint idle
  billing. For a workload this size (44 zones, sub-second batch inference),
  a real-time SageMaker endpoint would be a second billed, always-on
  resource serving a job the calling Lambda can already do inside its own
  memory budget.

The architecture keeps both options live and switchable by one environment
variable specifically so this isn't a one-way decision — see
`AWS_ARCHITECTURE.md` "Why Lambda-local ML, not API-only inference."

## Does this scale?

- **Compute**: Lambda scales horizontally with concurrent requests by
  design; the model load is amortized across warm invocations via the
  module-level cache, so cold-start cost (loading `booster.json` from S3)
  is paid once per container, not once per request. The 5-minute
  EventBridge keep-warm rule (`OBSERVABILITY.md`) keeps the 4
  contract-serving functions warm continuously during expected traffic.
- **Batching**: `predict_batch` already takes N zones in one model call —
  the heatmap's 44-zone read is one inference call, not 44. This is the
  change that matters most for scale: it's O(1) model calls per dashboard
  refresh regardless of zone count, not O(zones).
- **Failure isolation**: the circuit breaker (`ML_PIPELINE.md`) means a
  degraded ML tier doesn't compound into cascading retries under load — a
  failing tier is skipped for 5 minutes, not re-attempted on every request.
- **What would need to change at real production scale**: DynamoDB scans
  in a few hot paths (see `DATABASE_SCHEMA.md`'s GSI note) would need
  converting to `Query`-only access as incident volume grows past what a
  small scan comfortably serves; the model itself, at 300 trees over 17
  features, has no scaling concern of its own.

## What's the innovation here, stated plainly?

Not "we used AI" — every SOS app claims that. The specific, checkable
claims: (1) response-time and reporting-delay as first-class engineered
features, not incidental data columns; (2) a 3-tier inference resolver
with a circuit breaker, so ML availability degrades gracefully instead of
taking `/predict` down; (3) batched inference making the heatmap O(1)
model calls instead of O(zones); (4) full label-construction transparency
— the exact formula that produced every training row's risk_level is
documented, not hidden behind "the model decided." See
[`USP_AND_INNOVATION.md`](USP_AND_INNOVATION.md) for how this compares to
typical SOS apps feature-by-feature.
