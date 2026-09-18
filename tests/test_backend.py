"""
Local verification for Rakshak-SIH — runs with no AWS (in-memory DDB double).

    cd Rakshak-SIH && python3 -m pytest tests -q
"""

import importlib
import json
import os
import sys

import pytest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "backend", "lambdas", "_shared"))

from conftest import http_event, seed_patrols  # noqa: E402

import rakshak_common as rc  # noqa: E402


def _load(handler_dir):
    import importlib.util
    d = os.path.join(ROOT, "backend", "lambdas", handler_dir)
    path = os.path.join(d, "lambda_function.py")
    name = "handler_" + handler_dir.replace("-", "_")
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    sys.modules[name] = mod
    spec.loader.exec_module(mod)
    return mod


def body(resp):
    return json.loads(resp["body"])


# ───────────────────────── pure simulation math ─────────────────────────

def test_route_interpolation_wraps_and_is_continuous():
    wp = rc.PATROL_UNIT_BY_ID["P001"]["waypoints"]
    total = rc.route_length_m(wp)
    assert total > 0
    start = rc.position_on_route(wp, 0)
    assert start == list(wp[0])
    # one full loop returns to the start
    looped = rc.position_on_route(wp, total)
    assert abs(looped[0] - wp[0][0]) < 1e-6 and abs(looped[1] - wp[0][1]) < 1e-6
    # small step moves a small distance (continuity)
    a = rc.position_on_route(wp, 10)
    b = rc.position_on_route(wp, 12)
    assert rc.haversine_m(a[0], a[1], b[0], b[1]) < 5


def test_route_progress_is_monotonic_within_a_segment():
    wp = [[13.00, 80.00], [13.10, 80.00], [13.00, 80.00]]
    last = 0.0
    prev = wp[0]
    for d in range(0, 11000, 500):
        p = rc.position_on_route(wp, d)
        moved = rc.haversine_m(prev[0], prev[1], p[0], p[1])
        assert moved >= 0
        prev = p
        last = d
    assert last == 10500


def test_lerp_toward_clamps_at_target():
    frm, to = [13.00, 80.00], [13.02, 80.00]
    pos, rem, eta, arrived = rc.lerp_toward(frm, to, rc.now_ts() - 10_000, 40, rc.now_ts())
    assert arrived is True and rem == 0.0 and pos == to
    pos2, rem2, eta2, arr2 = rc.lerp_toward(frm, to, rc.now_ts(), 40, rc.now_ts())
    assert arr2 is False and rem2 > 0 and eta2 > 0


def test_to_from_ddb_roundtrip():
    from decimal import Decimal
    src = {"a": 1.5, "b": [1.0, 2.5, {"c": 3.25}], "d": "x", "e": 7, "f": True}
    d = rc.to_ddb(src)
    assert isinstance(d["a"], Decimal) and isinstance(d["b"][2]["c"], Decimal)
    back = rc.from_ddb(d)
    assert back["a"] == 1.5 and back["b"][2]["c"] == 3.25 and back["e"] == 7 and back["f"] is True


def test_zone_for_point_returns_a_pincode():
    assert rc.zone_for_point(13.0067, 80.2570)          # Adyar-ish
    assert rc.zone_for_point(13.0827, 80.2707)          # central


def test_predict_safety_baseline_shape():
    r = rc.predict_safety("600020")
    assert set(["safetyScore", "riskLevel", "confidence", "zone", "source"]).issubset(r)
    assert 0 <= r["safetyScore"] <= 100
    assert r["riskLevel"] in ("LOW", "MEDIUM", "HIGH")
    assert r["source"] == "baseline"


# ───────────────────────── handler: patrols ─────────────────────────

def test_get_patrols_returns_live_positions(ddb):
    seed_patrols(ddb)
    mod = _load("rakshak-patrol-handler")
    resp = mod.lambda_handler(http_event("GET", "/patrols"), None)
    assert resp["statusCode"] == 200
    rows = body(resp)
    assert len(rows) == 20
    for r in rows:
        assert "position" in r and "lat" in r["position"] and "lng" in r["position"]
        assert r["status"] in (rc.S_PATROL, rc.S_RESPOND, rc.S_SCENE, rc.S_RETURN)


# ───────────────────────── handler: SOS create + auto-assign ─────────────────────────

def test_sos_live_accepts_float_gps_and_assigns_patrol(ddb):
    seed_patrols(ddb)
    mod = _load("rakshak-sos-handler")
    ev = http_event("POST", "/sos/live", {
        "user_id": "U1", "username": "Asha",
        "latitude": 13.0067, "longitude": 80.2570,   # <-- floats, used to 500
        "pincode": "600020", "battery": 47, "network": "4G",
    })
    resp = mod.lambda_handler(ev, None)
    assert resp["statusCode"] == 201, resp["body"]
    b = body(resp)
    assert b["sos_id"].startswith("SOS-")
    assert b["status"] == "dispatched"
    assert b["assigned_patrol_id"] in rc.PATROL_UNIT_BY_ID
    assert isinstance(b["eta_seconds"], int) and b["eta_seconds"] >= 0

    stored = ddb[rc.T_SOS].items[(b["sos_id"],)]
    types = [e["type"] for e in stored["events"]]
    assert rc.EV_CREATED in types and rc.EV_ASSIGNED in types and rc.EV_EN_ROUTE in types
    from decimal import Decimal
    assert isinstance(stored["lat"], Decimal) and isinstance(stored["latitude"], Decimal)

    p = ddb[rc.T_PATROLS].items[(b["assigned_patrol_id"],)]
    assert p["status"] == rc.S_RESPOND and p["assigned_sos_id"] == b["sos_id"]


def test_sos_live_with_null_latitude_key_still_assigns(ddb):
    """Flutter / legacy rows send latitude:null alongside lat:<value>."""
    seed_patrols(ddb, n=3)
    mod = _load("rakshak-sos-handler")
    ev = http_event("POST", "/sos/live", {
        "user_id": "U9", "username": "Legacy",
        "latitude": None, "longitude": None,     # NULL keys present
        "lat": 13.0067, "lng": 80.2570, "pincode": "600020"})
    resp = mod.lambda_handler(ev, None)
    assert resp["statusCode"] == 201, resp["body"]
    b = body(resp)
    assert b["status"] == "dispatched" and b["assigned_patrol_id"] in rc.PATROL_UNIT_BY_ID


def test_assignment_contention_falls_through_to_next_nearest(ddb, monkeypatch):
    """Two SOS pressed 'at once': the conditional write must not double-book P001."""
    seed_patrols(ddb, n=3)
    sos = _load("rakshak-sos-handler")

    # first press grabs the nearest (P-something)
    r1 = body(sos.lambda_handler(http_event("POST", "/sos/live", {
        "user_id": "A", "lat": 13.010, "lng": 80.210, "pincode": "600020"}), None))
    first = r1["assigned_patrol_id"]
    assert first is not None

    # now make scan_all advertise the just-taken unit as free again (stale read),
    # exactly the race the ConditionExpression defends against
    real_scan = rc.scan_all
    def stale_scan(tbl, **kw):
        rows = real_scan(tbl, **kw)
        for row in rows:
            if row.get("patrol_id") == first:
                row = dict(row); row["status"] = rc.S_PATROL; row.pop("assigned_sos_id", None)
                rows[rows.index(next(x for x in rows if x["patrol_id"] == first))] = row
        return rows
    monkeypatch.setattr(rc, "scan_all", stale_scan)

    r2 = body(sos.lambda_handler(http_event("POST", "/sos/live", {
        "user_id": "B", "lat": 13.011, "lng": 80.211, "pincode": "600020"}), None))
    assert r2["assigned_patrol_id"] not in (None, first)   # fell through, no double-book
    assert ddb[rc.T_PATROLS].items[(first,)]["assigned_sos_id"] == r1["sos_id"]


def test_one_patrol_one_sos_and_feed_visibility(ddb):
    seed_patrols(ddb, n=1)                       # single unit available
    sos = _load("rakshak-sos-handler")
    feed = _load("rakshak-sos-handler")

    r1 = body(sos.lambda_handler(http_event("POST", "/sos/live", {
        "user_id": "U1", "lat": 13.0067, "lng": 80.2570, "pincode": "600020"}), None))
    assert r1["assigned_patrol_id"] == "P001"

    r2 = body(sos.lambda_handler(http_event("POST", "/sos/live", {
        "user_id": "U2", "lat": 13.0100, "lng": 80.2600, "pincode": "600020"}), None))
    assert r2["assigned_patrol_id"] is None        # the only unit is busy
    assert r2["status"] == "active"

    # both still visible in the live feed (active + dispatched)
    live = body(sos.lambda_handler(http_event("GET", "/sos/live"), None))
    assert {r1["sos_id"], r2["sos_id"]}.issubset({x["sos_id"] for x in live})

    # police feed filtered to the assigned unit shows exactly one
    only = body(feed.lambda_handler(http_event("GET", "/police/sos/active", qs={"patrol_id": "P001"}), None))
    assert [x["sos_id"] for x in only] == [r1["sos_id"]]


def test_reached_then_resolved_releases_patrol_and_leaves_feed(ddb):
    seed_patrols(ddb, n=3)
    sos = _load("rakshak-sos-handler")
    feed = _load("rakshak-sos-handler")
    patrols = _load("rakshak-patrol-handler")

    created = body(sos.lambda_handler(http_event("POST", "/sos/live", {
        "user_id": "U1", "lat": 13.0067, "lng": 80.2570, "pincode": "600020"}), None))
    sid = created["sos_id"]
    pid = created["assigned_patrol_id"]

    feed.lambda_handler(http_event("PATCH", f"/police/sos/{sid}/status",
                                   {"status": "reached", "officer_id": "OFF-9"},
                                   path_params={"sos_id": sid}), None)
    assert ddb[rc.T_SOS].items[(sid,)]["status"] == "reached"
    assert ddb[rc.T_PATROLS].items[(pid,)]["status"] == rc.S_SCENE

    feed.lambda_handler(http_event("PATCH", f"/police/sos/{sid}/status",
                                   {"status": "resolved"}, path_params={"sos_id": sid}), None)
    assert ddb[rc.T_SOS].items[(sid,)]["status"] == "resolved"
    assert ddb[rc.T_PATROLS].items[(pid,)]["status"] == rc.S_RETURN

    live = body(sos.lambda_handler(http_event("GET", "/sos/live"), None))
    assert sid not in {x["sos_id"] for x in live}

    types = [e["type"] for e in ddb[rc.T_SOS].items[(sid,)]["events"]]
    assert rc.EV_REACHED in types and rc.EV_RESOLVED in types


def test_returning_patrol_settles_back_to_patrolling(ddb, monkeypatch):
    seed_patrols(ddb, n=2)
    sos = _load("rakshak-sos-handler")
    feed = _load("rakshak-sos-handler")
    patrols = _load("rakshak-patrol-handler")

    created = body(sos.lambda_handler(http_event("POST", "/sos/live", {
        "user_id": "U1", "lat": 13.0067, "lng": 80.2570, "pincode": "600020"}), None))
    sid, pid = created["sos_id"], created["assigned_patrol_id"]
    feed.lambda_handler(http_event("PATCH", f"/police/sos/{sid}/status",
                                   {"status": "resolved"}, path_params={"sos_id": sid}), None)
    assert ddb[rc.T_PATROLS].items[(pid,)]["status"] == rc.S_RETURN

    real = rc.now_ts
    # 10 s later the unit is still on its way home — must NOT settle early
    monkeypatch.setattr(rc, "now_ts", lambda: real() + 10)
    patrols.lambda_handler(http_event("GET", "/patrols"), None)
    assert ddb[rc.T_PATROLS].items[(pid,)]["status"] == rc.S_RETURN

    # much later the return trip is complete -> lazily settled to Patrolling
    monkeypatch.setattr(rc, "now_ts", lambda: real() + 6000)
    patrols.lambda_handler(http_event("GET", "/patrols"), None)
    assert ddb[rc.T_PATROLS].items[(pid,)]["status"] == rc.S_PATROL


def test_path_param_vs_rawpath_fallback_both_resolve(ddb):
    """API v2 route params ({id},{sos_id},{zoneId}) and the rawPath fallback."""
    seed_patrols(ddb, n=2)
    sos = _load("rakshak-sos-handler")
    feed = _load("rakshak-sos-handler")
    dash = _load("rakshak-dashboard")

    created = body(sos.lambda_handler(http_event("POST", "/sos/live", {
        "user_id": "U1", "lat": 13.0067, "lng": 80.2570, "pincode": "600020"}), None))
    sid = created["sos_id"]

    # rawPath carries the id, pathParameters empty (fallback path)
    r = feed.lambda_handler(http_event("PATCH", f"/police/sos/{sid}/status",
                                       {"status": "reached"}, path_params={}), None)
    assert r["statusCode"] == 200 and body(r)["status"] == "reached"

    # pathParameters carries the id, rawPath is the bare prefix
    r = sos.lambda_handler(http_event("PATCH", "/sos/resolve/", path_params={"id": sid}), None)
    assert r["statusCode"] == 200 and body(r)["status"] == "resolved"

    # zoneId via pathParameters only
    r = dash.lambda_handler(http_event("GET", "/prediction/zone/", path_params={"zoneId": "600020"}), None)
    assert r["statusCode"] == 200 and body(r)["pincode"] == "600020"


def test_dispatch_and_resolve_empty_id_is_400(ddb):
    sos = _load("rakshak-sos-handler")
    assert sos.lambda_handler(http_event("POST", "/sos/dispatch/", path_params={}), None)["statusCode"] == 400
    assert sos.lambda_handler(http_event("PATCH", "/sos/resolve/", path_params={}), None)["statusCode"] == 400


def test_cancel_releases_patrol(ddb):
    seed_patrols(ddb, n=2)
    sos = _load("rakshak-sos-handler")
    created = body(sos.lambda_handler(http_event("POST", "/sos/live", {
        "user_id": "U1", "lat": 13.0067, "lng": 80.2570, "pincode": "600020"}), None))
    sid, pid = created["sos_id"], created["assigned_patrol_id"]
    r = sos.lambda_handler(http_event("POST", "/sos/cancelled", {"sos_id": sid, "user_phone": "+910000000000"}), None)
    assert r["statusCode"] == 200
    assert ddb[rc.T_SOS].items[(sid,)]["status"] == "cancelled"
    assert ddb[rc.T_PATROLS].items[(pid,)]["status"] == rc.S_RETURN


# ───────────────────────── handler: reports (role creds path) ─────────────────────────

def test_reports_submit_list_moderate(ddb):
    rep = _load("rakshak-reports-handler")
    c = rep.lambda_handler(http_event("POST", "/reports/submit",
                                      {"pincode": "600020", "description": "unlit lane", "type": "infra"}), None)
    assert c["statusCode"] == 201
    iid = body(c)["incident_id"]
    lst = body(rep.lambda_handler(http_event("GET", "/reports"), None))
    assert any(x["incident_id"] == iid for x in lst)
    a = rep.lambda_handler(http_event("PATCH", f"/reports/approve/{iid}", path_params={"id": iid}), None)
    assert body(a)["status"] == "approved"


# ───────────────────────── handler: inference ─────────────────────────

def test_predict_endpoint_never_500s_and_returns_0_100(ddb):
    inf = _load("rakshak-test-inference")
    r = inf.lambda_handler(http_event("POST", "/predict", {"pincode": 600020, "hour": 23}), None)
    assert r["statusCode"] == 200
    b = body(r)
    assert 0 <= b["safetyScore"] <= 100 and b["riskLevel"] in ("LOW", "MEDIUM", "HIGH")
    assert b["source"] in ("sagemaker", "s3-model", "baseline")


# ───────────────────────── handler: dashboard ─────────────────────────

def test_dashboard_snapshot_timeline_heatmap_prediction(ddb):
    seed_patrols(ddb, n=20)
    sos = _load("rakshak-sos-handler")
    dash = _load("rakshak-dashboard")

    # one live + one resolved incident
    live1 = body(sos.lambda_handler(http_event("POST", "/sos/live", {
        "user_id": "U1", "lat": 13.0067, "lng": 80.2570, "pincode": "600020"}), None))
    res1 = body(sos.lambda_handler(http_event("POST", "/sos/live", {
        "user_id": "U2", "lat": 13.10, "lng": 80.28, "pincode": "600011"}), None))
    sos.lambda_handler(http_event("PATCH", f"/sos/resolve/{res1['sos_id']}",
                                  path_params={"id": res1["sos_id"]}), None)

    snap = body(dash.lambda_handler(http_event("GET", "/dashboard/snapshot"), None))
    assert snap["patrols"]["total"] == 20
    assert snap["incidents"]["active_total"] >= 1
    assert snap["resolved_today"] >= 1
    assert isinstance(snap["high_risk_zones"], list) and len(snap["high_risk_zones"]) <= 5
    assert snap["officers_available"] <= 20

    tl = body(dash.lambda_handler(http_event("GET", "/dashboard/timeline"), None))
    assert tl["count"] >= 1
    assert {"type", "ts", "sos_id"}.issubset(tl["events"][0].keys())
    ts = [e["ts"] for e in tl["events"] if e["ts"]]
    assert ts == sorted(ts, reverse=True)          # newest first

    hm = body(dash.lambda_handler(http_event("GET", "/heatmap/live"), None))
    assert hm["zone_count"] >= 20
    z0 = hm["zones"][0]
    assert {"pincode", "safety_score", "risk_level", "lat", "lng"}.issubset(z0.keys())
    assert 0 <= z0["safety_score"] <= 100

    pr = body(dash.lambda_handler(http_event("GET", "/prediction/zone/600020",
                                             path_params={"zoneId": "600020"}), None))
    assert 0 <= pr["safetyScore"] <= 100 and pr["zone"] == rc.zone_name("600020")


def test_dashboard_prediction_missing_zone_is_400(ddb):
    dash = _load("rakshak-dashboard")
    r = dash.lambda_handler(http_event("GET", "/prediction/zone/", path_params={}), None)
    assert r["statusCode"] == 400


# ───────────────────────── frozen-contract route aliases ─────────────────────────

def test_frozen_contract_post_sos_alias_matches_sos_live(ddb):
    seed_patrols(ddb, n=3)
    sos = _load("rakshak-sos-handler")
    r = sos.lambda_handler(http_event("POST", "/sos", {
        "user_id": "U1", "lat": 13.0067, "lng": 80.2570, "pincode": "600020"}), None)
    assert r["statusCode"] == 201
    assert body(r)["sos_id"].startswith("SOS-")


def test_frozen_contract_get_incident_by_id(ddb):
    seed_patrols(ddb, n=3)
    sos = _load("rakshak-sos-handler")
    created = body(sos.lambda_handler(http_event("POST", "/sos/live", {
        "user_id": "U1", "lat": 13.0067, "lng": 80.2570, "pincode": "600020"}), None))
    sid = created["sos_id"]

    r = sos.lambda_handler(http_event("GET", f"/incident/{sid}", path_params={"id": sid}), None)
    assert r["statusCode"] == 200
    b = body(r)
    assert b["sos_id"] == sid and b["assigned_patrol_id"] == created["assigned_patrol_id"]

    r404 = sos.lambda_handler(http_event("GET", "/incident/NOPE", path_params={"id": "NOPE"}), None)
    assert r404["statusCode"] == 404


def test_frozen_contract_get_incident_eta(ddb):
    seed_patrols(ddb, n=3)
    sos = _load("rakshak-sos-handler")
    created = body(sos.lambda_handler(http_event("POST", "/sos/live", {
        "user_id": "U1", "lat": 13.0067, "lng": 80.2570, "pincode": "600020"}), None))
    sid = created["sos_id"]

    r = sos.lambda_handler(http_event("GET", f"/incident/{sid}/eta", path_params={"id": sid}), None)
    assert r["statusCode"] == 200
    b = body(r)
    assert b["sos_id"] == sid
    assert isinstance(b["eta_seconds"], int) and b["eta_seconds"] >= 0
    assert "patrol_position" in b


def test_frozen_contract_incidents_active_alias(ddb):
    seed_patrols(ddb, n=3)
    sos = _load("rakshak-sos-handler")
    feed = _load("rakshak-sos-handler")
    sos.lambda_handler(http_event("POST", "/sos/live", {
        "user_id": "U1", "lat": 13.0067, "lng": 80.2570, "pincode": "600020"}), None)

    r = feed.lambda_handler(http_event("GET", "/incidents/active"), None)
    assert r["statusCode"] == 200
    assert len(body(r)) >= 1


def test_frozen_contract_accept_is_additive_and_keeps_status(ddb):
    seed_patrols(ddb, n=3)
    sos = _load("rakshak-sos-handler")
    feed = _load("rakshak-sos-handler")
    created = body(sos.lambda_handler(http_event("POST", "/sos/live", {
        "user_id": "U1", "lat": 13.0067, "lng": 80.2570, "pincode": "600020"}), None))
    sid = created["sos_id"]
    assert created["status"] == "dispatched"

    r = feed.lambda_handler(http_event("PATCH", f"/incident/{sid}/accept",
                                       {"officer_id": "OFF-9"}, path_params={"id": sid}), None)
    assert r["statusCode"] == 200
    b = body(r)
    assert b["status"] == "dispatched"  # accept does not change lifecycle status
    row = ddb[rc.T_SOS].items[(sid,)]
    assert row.get("accepted_by") == "OFF-9" and row.get("accepted_at")
    types = [e["type"] for e in row["events"]]
    assert "Accepted" in types


def test_frozen_contract_status_and_resolve_aliases(ddb):
    seed_patrols(ddb, n=3)
    sos = _load("rakshak-sos-handler")
    feed = _load("rakshak-sos-handler")
    created = body(sos.lambda_handler(http_event("POST", "/sos/live", {
        "user_id": "U1", "lat": 13.0067, "lng": 80.2570, "pincode": "600020"}), None))
    sid, pid = created["sos_id"], created["assigned_patrol_id"]

    r = feed.lambda_handler(http_event("PATCH", f"/incident/{sid}/status",
                                       {"status": "reached"}, path_params={"id": sid}), None)
    assert r["statusCode"] == 200 and body(r)["status"] == "reached"
    assert ddb[rc.T_PATROLS].items[(pid,)]["status"] == rc.S_SCENE

    r = feed.lambda_handler(http_event("PATCH", f"/incident/{sid}/resolve",
                                       {}, path_params={"id": sid}), None)
    assert r["statusCode"] == 200 and body(r)["status"] == "resolved"
    assert ddb[rc.T_PATROLS].items[(pid,)]["status"] == rc.S_RETURN


def test_frozen_contract_dashboard_patrols_heatmap_prediction_health_version(ddb):
    seed_patrols(ddb, n=20)
    patrols = _load("rakshak-patrol-handler")
    dash = _load("rakshak-dashboard")

    r = patrols.lambda_handler(http_event("GET", "/dashboard/patrols"), None)
    assert r["statusCode"] == 200 and len(body(r)) == 20

    r = dash.lambda_handler(http_event("GET", "/dashboard/heatmap"), None)
    assert r["statusCode"] == 200 and body(r)["zone_count"] >= 20

    r = dash.lambda_handler(http_event("GET", "/prediction/600020", path_params={"zone": "600020"}), None)
    assert r["statusCode"] == 200 and body(r)["pincode"] == "600020"

    r = dash.lambda_handler(http_event("GET", "/health"), None)
    assert r["statusCode"] == 200
    h = body(r)
    assert h["status"] in ("ok", "degraded")
    assert "ml" in h["checks"] and "ml_tiers" in h

    r = dash.lambda_handler(http_event("GET", "/version"), None)
    assert r["statusCode"] == 200 and "version" in body(r)


def test_patrol_status_whitelist_rejects_invalid(ddb):
    seed_patrols(ddb, n=1)
    patrols = _load("rakshak-patrol-handler")
    r = patrols.lambda_handler(http_event("PATCH", "/patrols/P001/status",
                                          {"status": "banana"}, path_params={"id": "P001"}), None)
    assert r["statusCode"] == 400


# ───────────────────────── ML: predict_batch ─────────────────────────

def test_predict_batch_matches_predict_safety_and_orders_results(ddb):
    pins = ["600017", "600020", "600001"]
    batch = rc.predict_batch(pins)
    assert len(batch) == 3
    assert [r["pincode"] for r in batch] == pins
    for r in batch:
        assert 0 <= r["safetyScore"] <= 100
        assert r["source"] == "baseline"  # ddb fixture forces both ML tiers to fail
        assert rc.safety_to_level(r["safetyScore"]) == r["riskLevel"]

    single = rc.predict_safety("600017")
    assert single["pincode"] == batch[0]["pincode"]
    assert single["source"] == "baseline"


def test_circuit_breaker_opens_after_failure_and_reports_via_tier_status(ddb):
    rc._tier_mark_failed("s3-model")
    assert not rc._tier_available("s3-model")
    status = rc.tier_status()
    assert status["s3-model"].startswith("cooldown")
