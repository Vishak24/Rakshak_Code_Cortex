"""
rakshak-patrol-handler — the single source of truth for live patrol state.

Routes (unchanged contract, additive fields only):
  GET    /patrols               live array; positions computed on read from routes
  POST   /patrol/optimize       static zone -> unit allocation (unchanged)
  PATCH  /patrols/{id}/status   manual status override (kept for ops/testing)

`GET /patrols` returns, per unit:
  patrol_id, name, officer, vehicle, zone, zone_name,
  status  (Patrolling | Responding | AtScene | Returning),
  position {lat, lng}, heading, eta_seconds, assigned_sos_id

Movement is derived from `cycle_start_ts` (patrolling) or the divert/return
anchor timestamps — no scheduler. A unit that has finished returning is lazily
settled back to Patrolling here.
"""

import rakshak_common as rc


def _patrols_table():
    return rc.table(rc.T_PATROLS)


def _list_patrols():
    now = rc.now_ts()
    rows = rc.scan_all(_patrols_table())
    # if the table was never seeded, still return the 20-unit roster so the
    # dashboard has something to render
    if not rows:
        rows = [{"patrol_id": u["patrol_id"], "name": u["name"], "officer": u["officer"],
                 "vehicle": u["vehicle"], "status": rc.S_PATROL, "cycle_start_ts": now - i * 37}
                for i, u in enumerate(rc.PATROL_UNITS)]

    out = []
    for row in rows:
        view = rc.compute_patrol_view(row, now)
        if view.pop("_settle_to_patrolling", False):
            try:
                rc.settle_patrol_to_patrolling(row["patrol_id"], now)
                view = rc.compute_patrol_view(
                    _patrols_table().get_item(Key={"patrol_id": row["patrol_id"]}).get("Item", row), now)
            except Exception:
                pass
        out.append(view)
    out.sort(key=lambda p: p.get("patrol_id", ""))
    return rc.ok(out)


def _optimize(event):
    body = rc.parse_body(event)
    zones = body.get("zones", [])
    UNITS = {"HIGH": 3, "MEDIUM": 2, "LOW": 1}
    ORDER = {"HIGH": 0, "MEDIUM": 1, "LOW": 2}
    REASON = {"HIGH": "Critical activity — 3 units recommended",
              "MEDIUM": "Elevated risk — 2 units recommended",
              "LOW": "Standard coverage — 1 unit recommended"}
    ranked = sorted(zones, key=lambda z: ORDER.get(str(z.get("risk_level", "LOW")).upper(), 2))
    deployment = []
    for z in ranked:
        risk = str(z.get("risk_level", "LOW")).upper()
        pin = str(z.get("pincode", ""))
        deployment.append({
            "pincode": pin,
            "name": z.get("name") or z.get("zone_name") or rc.zone_name(pin),
            "priority": risk,
            "suggested_units": UNITS.get(risk, 1),
            "reason": REASON.get(risk, "Standard coverage"),
        })
    return rc.ok({"deployment_zones": deployment})


_VALID_PATROL_STATUSES = {rc.S_PATROL, rc.S_RESPOND, rc.S_SCENE, rc.S_RETURN}


def _set_status(event, patrol_id):
    if not patrol_id:
        return rc.bad_request("patrol_id required")
    body = rc.parse_body(event)
    new_status = body.get("status", "Patrolling")
    if new_status not in _VALID_PATROL_STATUSES:
        return rc.bad_request(f"status must be one of {sorted(_VALID_PATROL_STATUSES)}, got {new_status!r}")
    upd = "SET #s = :s, updated_at = :t"
    vals = {":s": new_status, ":t": rc.now_iso()}
    if new_status == rc.S_PATROL:
        # Forcing a unit back onto its route: re-anchor it and clear any
        # divert/return state so it doesn't jump using stale coordinates.
        upd += (", cycle_start_ts = :c REMOVE assigned_sos_id, sos_lat, sos_lng, "
                "divert_start_ts, divert_from_lat, divert_from_lng, "
                "return_start_ts, return_from_lat, return_from_lng")
        vals[":c"] = rc.to_ddb(rc.now_ts())
    _patrols_table().update_item(
        Key={"patrol_id": patrol_id}, UpdateExpression=upd,
        ExpressionAttributeNames={"#s": "status"},
        ExpressionAttributeValues=rc.to_ddb(vals))
    return rc.ok({"patrol_id": patrol_id, "status": new_status})


def lambda_handler(event, context):
    if isinstance(event, dict) and event.get("warm"):
        return {"warm": True}
    if rc.is_options(event):
        return rc.preflight()
    method = rc.http_method(event)
    path = rc.http_path(event)
    pp = rc.path_params(event)
    try:
        if method == "POST" and path.endswith("/patrol/optimize"):
            return _optimize(event)
        if method == "PATCH" and "/patrols/" in path and path.endswith("/status"):
            pid = pp.get("id") or path.split("/patrols/")[-1].split("/status")[0].strip("/")
            return _set_status(event, pid)
        if method == "GET":
            return _list_patrols()
        return rc.not_found("route not found")
    except Exception as e:  # pragma: no cover
        return rc.server_error(e)
