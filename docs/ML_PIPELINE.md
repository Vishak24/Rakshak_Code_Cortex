# ML Pipeline

Two model generations exist. **v2 is what's deployed and served in
production** — the pipeline below documents both, but every "currently"
statement refers to v2 unless marked v1.

| | v1 (`ml/train_chennai_risk_model.py` output) | v2 (deployed) |
|---|---|---|
| Trained | 2026-02-18 | ~2026-04-17 |
| Training rows | 15,000 (20 zones) | 20,800 (44 zones) |
| `n_estimators` | 200 | 300 |
| xgboost version | sklearn `XGBClassifier` wrapper | raw `xgb.Booster` API, xgboost 3.2 |
| Objective | default (`multi:softprob` via `XGBClassifier`) | explicit `multi:softprob` |
| Saved as | `.pkl` (joblib) + `.json` (xgboost native) | **standalone `booster.json` only** — no `.pkl`, no sklearn wrapper dependency at inference time |
| Test accuracy | **1.0** (12,000 train / 3,000 test split) | not preserved in a metadata file this pass — see "Reading the accuracy numbers honestly" below |
| CV mean accuracy | 0.99975 (± 0.0005, 5-fold) | not preserved |

v1's exact metrics are in `ml/train_chennai_risk_model.py`'s
output shape and were verified from the source archive's
`model_metadata.json` (not copied into this repo — S3 is the artifact
store, per `DEPLOYMENT.md`; v1's `.pkl`/`.json` artifacts are superseded by
v2 and were excluded from this migration). v2's own metadata file was not
located in the source archive; what's independently verifiable about v2
is documented below (booster hyperparameters read directly from the
deployed model, and an exact-parity check against a held-out validation
set performed when v2's inference path was last debugged).

## Training pipeline (v1 script, `ml/train_chennai_risk_model.py`)

1. Load `chennai_sos_enhanced_data.csv` (or the v2 equivalent,
   `chennai_sos_enhanced_data_v2.csv`, for the production model).
2. Label-encode `area` and `neighborhood` with `sklearn.LabelEncoder`,
   persisting the encoders (`label_encoder_area.pkl`,
   `label_encoder_neighborhood.pkl`) so inference can reproduce the exact
   same integer mapping.
3. Select the 17-column `feature_columns` (see `FEATURE_ENGINEERING.md`).
4. `train_test_split(test_size=0.2, random_state=42, stratify=y)`.
5. Fit `XGBClassifier(n_estimators=200, max_depth=6, learning_rate=0.1,
   subsample=0.8, colsample_bytree=0.8, random_state=42,
   eval_metric='mlogloss')`.
6. Evaluate: accuracy, classification report, confusion matrix, 5-fold CV.
7. Save `model.save_model(...)` (native xgboost JSON), `joblib.dump` (pkl),
   both label encoders, and `model_metadata.json` (features, importances,
   accuracy, CV stats, hyperparameters — a full audit trail).

v2's production training extended this same pipeline to the 44-zone,
20,800-row dataset with `n_estimators=300` and exported to the raw
`xgb.Booster` save format instead of the sklearn wrapper — a deliberate
choice for the **inference** side (see below), not a change to the
feature engineering or label logic, both of which are unchanged from v1.

## Preprocessing at inference time

`rakshak_common._vector_for(pincode, overrides, when)` builds the same
17-value feature vector the model was trained on:

1. Look up the zone's static profile (lat/lng, area/neighborhood encoding)
   from the hand-authored pincode table.
2. Derive the temporal features (`hour`, `day_of_week`, `is_night`, etc.)
   from `when` (defaults to "now").
3. Fill `reporting_delay_minutes`, `response_time_minutes`,
   `signal_count_last_7d/30d`, `signal_density_ratio`, `victim_age` from
   `FEATURE_DEFAULTS` unless the caller supplies overrides (`POST /predict`
   accepts any of the 17 features as an override).
4. Order the vector exactly as `FEATURE_ORDER` — this ordering **must**
   match training's `feature_columns` list or the model silently
   mispredicts; the two lists are kept in lockstep by inspection (both are
   short, both are documented in `FEATURE_ENGINEERING.md`).

## Evaluation — reading the accuracy numbers honestly

v1's headline numbers (**1.0 test accuracy, 0.99975 CV**) look implausibly
perfect, and the honest explanation is exactly that: they *are* near-perfect
by construction, not by coincidence. `risk_level` is generated from an
explicit formula over a subset of the same features the model trains on
(see `FEATURE_ENGINEERING.md` "Label construction") — the model is learning
to invert a deterministic rule, which XGBoost does essentially perfectly
given the rule is expressible as a handful of threshold splits over
`base_risk`, `is_night`, `signal_count_last_7d`, `response_time_minutes`,
and `reporting_delay_minutes`. The v1 feature-importance ranking confirms
this directly: `latitude` (0.26, the strongest proxy for the generator's
per-area `base_risk`) and `signal_count_last_30d` (0.15) dominate, together
with `pincode` (0.14) — three ways of recovering the same underlying
per-area risk assignment the label was built from.

**This accuracy is not evidence of real-world predictive power** and should
not be presented as such — it is evidence the model correctly learned the
synthetic generator's rule, which is the right thing to check given the
data is synthetic (`DATASET_CARD.md`), but is a different claim from "this
model predicts real Chennai safety outcomes."

## Inference pipeline: the 3-tier resolver

`rakshak_common.predict_batch(pincodes, when, overrides)` — every
prediction, single or batch, goes through one function with three tiers,
falling through on failure with a **circuit breaker** so a dead tier isn't
retried on every request:

```
tier 1: SageMaker endpoint (env-gated — only attempted if
         SAGEMAKER_ENDPOINT is set)
  │ fails / not configured
  ▼
tier 2: S3-cached local model — xgb.Booster().load_model() from
         models/v2/booster.json, cached as a module-level global so a warm
         Lambda container reuses it across invocations. inplace_predict()
         on a numpy matrix, falling back to DMatrix if unavailable.
  │ fails
  ▼
tier 3: deterministic per-zone baseline — a fixed function of the zone's
         static profile, never fails, always returns a plausible score
```

**Circuit breaker**: `TIER_COOLDOWN_S = 300`. When a tier throws, it's
marked failed for 5 minutes (`_tier_mark_failed`) and skipped on
subsequent calls within that window (`_tier_available`) — so a genuinely
down SageMaker endpoint costs one timeout, not one timeout per request for
5 minutes straight. `GET /health`'s `tier_status()` exposes current
breaker state.

**Batching**: `predict_batch` takes N pincodes and makes **one** model call
over an N-row matrix, not N sequential single-row calls — this is what
brought `GET /dashboard/heatmap` (44 zones) from a multi-second, 44-call
response down to a single sub-200ms response. `predict_safety()` (single
zone) is now a thin wrapper calling `predict_batch([pincode])`.

**Verified live**: `deploy/verify.sh`'s ML-tier check confirms
`source: "s3-model"` (not `"baseline"`) on every deployed prediction, and
the heatmap check confirms all 44 zones score from the real model, not the
fallback. An exact-parity check against a held-out `validation.json`
ground-truth set (produced from the same training data split) was run when
the S3-model tier's `xgb.Booster` loading path was last debugged, and
matched the training-time predictions exactly for that model version.
