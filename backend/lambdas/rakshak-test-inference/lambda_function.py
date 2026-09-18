"""
rakshak-test-inference — AI Safety Score behind  POST /predict.

Fix vs previously deployed version:
  * Old handler called invoke_endpoint('rakshak-risk-endpoint') unconditionally
    -> 500 (endpoint deleted). This version uses the shared 3-tier resolver:
        1. SageMaker endpoint (if it exists)
        2. XGBoost/RF model from S3 (needs the rakshak-ml-layer)
        3. deterministic per-zone baseline (always works)

Response (0-100 safety, spec shape + a `source` tag for demo transparency):
  { "safetyScore": 82, "riskLevel": "HIGH", "confidence": 0.91,
    "zone": "Adyar", "pincode": "600020", "source": "s3-model" }
"""

import rakshak_common as rc


def _resolve_pincode(body):
    pin = body.get("pincode") or body.get("zone_id") or body.get("zoneId")
    if pin:
        return str(int(pin)) if str(pin).isdigit() else str(pin)
    lat = body.get("latitude", body.get("lat"))
    lng = body.get("longitude", body.get("lng"))
    if lat is not None and lng is not None:
        try:
            return rc.zone_for_point(float(lat), float(lng))
        except (TypeError, ValueError):
            pass
    return "600001"


def lambda_handler(event, context):
    if isinstance(event, dict) and event.get("warm"):
        return {"warm": True}
    if rc.is_options(event):
        return rc.preflight()
    try:
        body = rc.parse_body(event)
        pincode = _resolve_pincode(body)
        # An explicitly supplied pincode outside the 44 serviced zones is a
        # caller error, not something to answer with a confident fabrication.
        if body.get("pincode") and not rc.is_known_zone(pincode):
            return rc.not_found(f"pincode {pincode} is not a serviced Chennai zone")

        # optional caller overrides for the 17 model features
        overrides = {k: body[k] for k in rc.FEATURE_ORDER if k in body}
        for a, b in (("lat", "latitude"), ("lon", "longitude"), ("lng", "longitude")):
            if a in body and b not in overrides:
                overrides[b] = body[a]

        result = rc.predict_safety(pincode, features=overrides or None)
        return rc.ok(result)
    except Exception as e:  # pragma: no cover
        # never 500 the score endpoint — fall back hard
        try:
            return rc.ok(rc._baseline_prediction(_resolve_pincode(rc.parse_body(event))))
        except Exception:
            return rc.server_error(e)
