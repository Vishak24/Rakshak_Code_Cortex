"""
SageMaker inference handler for rakshak-risk-endpoint (Chennai risk model, v2 XGBoost).

Contract expected by rakshak_common.predict_safety():
  request : {"instances": [[<17 floats>], ...]}
  response: {"predictions": [<int class>, ...], "probabilities": [[p_low, p_med, p_high], ...]}

Loads the sklearn-wrapper pickle when the container's xgboost matches (it does: 3.2-0);
falls back to the raw booster JSON so the artifact stays usable on any xgboost >= 1.7.
"""
import json
import os

import numpy as np

FEATURE_COUNT = 17
_IS_SKLEARN = False


def model_fn(model_dir):
    global _IS_SKLEARN
    # 1) primary: sklearn XGBClassifier pickle (keeps classes_ + predict_proba)
    pkl = os.path.join(model_dir, "model.pkl")
    if os.path.exists(pkl):
        try:
            import joblib
            m = joblib.load(pkl)
            _IS_SKLEARN = True
            return m
        except Exception as e:  # noqa: BLE001
            print(f"[inference] pickle load failed ({e!r}); falling back to booster JSON")
    # 2) fallback: raw booster JSON
    import xgboost as xgb
    booster = xgb.Booster()
    for cand in ("xgb_model.json", "booster.json"):
        p = os.path.join(model_dir, cand)
        if os.path.exists(p):
            booster.load_model(p)
            _IS_SKLEARN = False
            return booster
    raise FileNotFoundError("no model.pkl / xgb_model.json / booster.json in model dir")


def input_fn(request_body, content_type="application/json"):
    if isinstance(request_body, (bytes, bytearray)):
        request_body = request_body.decode("utf-8")
    if "csv" in (content_type or ""):
        rows = [r for r in request_body.strip().splitlines() if r]
        arr = np.array([[float(x) for x in r.split(",")] for r in rows], dtype=float)
    else:
        payload = json.loads(request_body)
        if isinstance(payload, dict):
            data = payload.get("instances", payload.get("features", payload.get("inputs")))
        else:
            data = payload
        arr = np.asarray(data, dtype=float)
    if arr.ndim == 1:
        arr = arr.reshape(1, -1)
    if arr.shape[1] != FEATURE_COUNT:
        raise ValueError(f"expected {FEATURE_COUNT} features, got {arr.shape[1]}")
    return arr


def predict_fn(input_data, model):
    if _IS_SKLEARN:
        proba = np.asarray(model.predict_proba(input_data), dtype=float)
        preds = np.asarray(model.predict(input_data)).astype(int)
    else:
        import xgboost as xgb
        try:
            proba = np.asarray(model.inplace_predict(input_data), dtype=float)
        except Exception:  # noqa: BLE001
            proba = np.asarray(model.predict(xgb.DMatrix(input_data)), dtype=float)
        if proba.ndim == 1:  # binary -> [1-p, p]
            proba = np.column_stack([1.0 - proba, proba])
        preds = proba.argmax(axis=1).astype(int)
    return {"predictions": preds.tolist(), "probabilities": proba.tolist()}


def output_fn(prediction, accept="application/json"):
    return json.dumps(prediction), "application/json"
