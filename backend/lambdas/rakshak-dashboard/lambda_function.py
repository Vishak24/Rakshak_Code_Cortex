"""
rakshak-dashboard — NEW Lambda for the Central Command dashboard aggregates.

Routes (all new, additive to API aksdwfbnn5):
  GET  /dashboard/snapshot          headline counters
  GET  /dashboard/timeline          chronological incident events (all incidents)
  GET  /heatmap/live                per-zone safety score + incident density
  GET  /prediction/zone/{zoneId}    on-demand AI safety score for one pincode

Reads only: rakshak-patrols, rakshak-sos-alerts. No writes.
Carries the rakshak-ml-layer so /prediction/zone can run S3 inference.
"""

import os

import rakshak_common as rc

LIVE_STATES = ("active", "dispatched", "reached")
BUILD_VERSION = "1.0.0"  # bump on deploy; overridable via BUILD_VERSION env


def _patrol_rows():
    rows = rc.scan_all(rc.table(rc.T_PATROLS))
    if not rows:
        now = rc.now_ts()
        rows = [{"patrol_id": u["patrol_id"], "status": rc.S_PATROL, "cycle_start_ts": now}
                for u in rc.PATROL_UNITS]
    return rows


def _snapshot(event):
    now = rc.now_ts()
    start_utc, end_utc = rc.ist_day_bounds_utc()

    patrols = _patrol_rows()
    pc = {"Patrolling": 0, "Responding": 0, "AtScene": 0, "Returning": 0}
    for p in patrols:
        pc[p.get("status") or "Patrolling"] = pc.get(p.get("status") or "Patrolling", 0) + 1

    sos = rc.scan_all(rc.table(rc.T_SOS))
    active = [s for s in sos if s.get("status") in LIVE_STATES]
    resolved_today = [s for s in sos if s.get("status") == "resolved"
                      and rc.iso_within(s.get("resolved_at"), start_utc, end_utc)]
    cancelled_today = [s for s in sos if s.get("status") == "cancelled"
                       and rc.iso_within(s.get("cancelled_at"), start_utc, end_utc)]

    # high-risk zones — model-scored, top 5 by risk
    zone_scores = _zone_scores(sos)
    high = sorted(zone_scores, key=lambda z: z["safety_score"])[:5]

    by_state = {"active": 0, "dispatched": 0, "reached": 0}
    for s in active:
        by_state[s.get("status", "active")] = by_state.get(s.get("status", "active"), 0) + 1

    return rc.ok({
        "generated_at": rc.now_iso(),
        "patrols": {
            "total": len(patrols),
            "on_patrol": pc.get("Patrolling", 0),
            "responding": pc.get("Responding", 0),
            "at_scene": pc.get("AtScene", 0),
            "returning": pc.get("Returning", 0),
        },
        "officers_available": pc.get("Patrolling", 0),
        "officers_on_duty": len(patrols),
        "incidents": {
            "active_total": len(active),
            "awaiting": by_state.get("active", 0),
            "dispatched": by_state.get("dispatched", 0),
            "on_scene": by_state.get("reached", 0),
        },
        "resolved_today": len(resolved_today),
        "cancelled_today": len(cancelled_today),
        "high_risk_zones": [
            {"pincode": z["pincode"], "zone_name": z["zone_name"],
             "safety_score": z["safety_score"], "risk_level": z["risk_level"]}
            for z in high
        ],
        "active_incident_ids": [s.get("sos_id") for s in active],
    })


def _timeline(event):
    qs = rc.query_params(event)
    try:
        limit = min(int(qs.get("limit", 100)), 500)
    except (TypeError, ValueError):
        limit = 100

    sos = rc.scan_all(rc.table(rc.T_SOS))
    events = []
    for s in sos:
        s = rc.from_ddb(s)
        base = {"sos_id": s.get("sos_id"), "pincode": s.get("pincode"),
                "zone_name": s.get("zone_name") or rc.zone_name(s.get("pincode"))}
        evs = s.get("events") or []
        if evs:
            for e in evs:
                events.append({**base, "type": e.get("type"), "ts": e.get("ts"),
                               "detail": e.get("detail", ""), "patrol_id": e.get("patrol_id")})
        else:
            # synthesise from timestamps for legacy rows with no events[]
            for label, key in ((rc.EV_CREATED, "created_at"), (rc.EV_ASSIGNED, "dispatched_at"),
                               (rc.EV_REACHED, "reached_at"), (rc.EV_RESOLVED, "resolved_at"),
                               (rc.EV_CANCELLED, "cancelled_at")):
                if s.get(key):
                    events.append({**base, "type": label, "ts": s[key], "detail": "", "patrol_id": s.get("assigned_patrol_id")})

    events.sort(key=lambda e: e.get("ts") or "", reverse=True)
    return rc.ok({"generated_at": rc.now_iso(), "count": len(events[:limit]), "events": events[:limit]})


def _zone_scores(sos_rows=None):
    """One score per known pincode: model score adjusted by recent incident density."""
    if sos_rows is None:
        sos_rows = rc.scan_all(rc.table(rc.T_SOS))
    start_utc, end_utc = rc.ist_day_bounds_utc()
    dens_24h, active_now = {}, {}
    for s in sos_rows:
        pin = str(s.get("pincode") or "")
        if not pin:
            continue
        if s.get("status") in LIVE_STATES:
            active_now[pin] = active_now.get(pin, 0) + 1
        if rc.iso_within(s.get("created_at"), start_utc, end_utc):
            dens_24h[pin] = dens_24h.get(pin, 0) + 1

    # One call scores all 44 zones (single SageMaker/local-model invoke instead
    # of 44 sequential predict_safety() calls — this is what made /heatmap/live
    # and /dashboard/snapshot take ~3s when the ML tiers were failing).
    pins = list(rc.ZONE_COORDS.keys())
    preds = rc.predict_batch(pins)

    out = []
    for pin, pred in zip(pins, preds):
        lat, lng = rc.ZONE_COORDS[pin]
        score = pred["safetyScore"]
        # Incident density pulls the score down, but never to 0 — a headline
        # reading "0" is indistinguishable from "no data" on the dashboard.
        score = score - 6 * dens_24h.get(pin, 0) - 10 * active_now.get(pin, 0)
        score = int(max(rc.SAFETY_FLOOR, min(100, score)))
        # Same bands as every other tier, so the label can't contradict the number.
        level = rc.safety_to_level(score)
        out.append({
            "pincode": pin, "zone_name": rc.zone_name(pin),
            "lat": lat, "lng": lng,
            "safety_score": int(score), "risk_level": level,
            "incidents_today": dens_24h.get(pin, 0),
            "active_incidents": active_now.get(pin, 0),
            "source": pred["source"],
        })
    return out


def _heatmap(event):
    zones = _zone_scores()
    return rc.ok({"generated_at": rc.now_iso(), "zone_count": len(zones), "zones": zones})


def _prediction(event, zone_id):
    if not zone_id:
        return rc.bad_request("zoneId (pincode) required")
    if not rc.is_known_zone(zone_id):
        return rc.not_found(f"pincode {zone_id} is not a serviced Chennai zone")
    result = rc.predict_safety(str(zone_id))
    return rc.ok(result)


def _health(event):
    checks = {}
    ok_ = True
    for name, table in ((rc.T_PATROLS, rc.T_PATROLS), (rc.T_SOS, rc.T_SOS)):
        try:
            rc.table(table).get_item(Key={"patrol_id": "__health__"} if table == rc.T_PATROLS
                                     else {"sos_id": "__health__"})
            checks[f"dynamodb:{table}"] = "ok"
        except Exception as e:
            checks[f"dynamodb:{table}"] = f"error: {e}"
            ok_ = False
    # cheap ML liveness probe — reuses whatever tier is currently open, doesn't
    # force a call to a tier already in cooldown
    try:
        probe = rc.predict_safety("600017")
        checks["ml"] = probe["source"]
    except Exception as e:
        checks["ml"] = f"error: {e}"
        ok_ = False
    return rc.ok({
        "status": "ok" if ok_ else "degraded",
        "checks": checks,
        "ml_tiers": rc.tier_status(),
        "version": os.environ.get("BUILD_VERSION", BUILD_VERSION),
        "generated_at": rc.now_iso(),
    })


def _version(event):
    return rc.ok({"version": os.environ.get("BUILD_VERSION", BUILD_VERSION),
                  "generated_at": rc.now_iso()})


def lambda_handler(event, context):
    if isinstance(event, dict) and event.get("warm"):
        return {"warm": True}
    if rc.is_options(event):
        return rc.preflight()
    method = rc.http_method(event)
    path = rc.http_path(event)
    pp = rc.path_params(event)
    try:
        if method == "GET" and path.endswith("/dashboard/snapshot"):
            return _snapshot(event)
        if method == "GET" and path.endswith("/dashboard/timeline"):
            return _timeline(event)
        if method == "GET" and (path.endswith("/heatmap/live") or path.endswith("/dashboard/heatmap")):
            return _heatmap(event)
        if method == "GET" and "/prediction/zone/" in path:
            return _prediction(event, pp.get("zoneId") or path.split("/prediction/zone/")[-1].strip("/"))
        if method == "GET" and "/prediction/" in path and "/prediction/zone/" not in path:
            return _prediction(event, pp.get("zone") or path.split("/prediction/")[-1].strip("/"))
        if method == "GET" and path.endswith("/health"):
            return _health(event)
        if method == "GET" and path.endswith("/version"):
            return _version(event)
        return rc.not_found("route not found")
    except Exception as e:  # pragma: no cover
        return rc.server_error(e)
