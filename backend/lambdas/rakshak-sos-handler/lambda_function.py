"""
rakshak-sos-handler — SOS lifecycle, automatic dispatch, and the police-facing
feed + status transitions (merged from the retired rakshak-sos-feed function;
both always shared rakshak_common and had no cross-Lambda dependency).

Routes (unchanged contract, additive fields only):
  POST   /sos/live                    create incident, auto-assign nearest patrol, start timeline
  GET    /sos/live                    active feed (active | dispatched | reached); ?user_id= filter
  POST   /sos/dispatch/{id}           idempotent (re)dispatch — assigns a patrol if none yet
  PATCH  /sos/resolve/{id}            resolve incident, send patrol back to route
  POST   /sos/cancelled               citizen cancels own incident, send patrol back to route
  GET    /police/sos/active           police feed; ?patrol_id=  ?officer_lat=&officer_lng=
  PATCH  /police/sos/{sos_id}/status  officer transitions status (dispatched/reached/resolved/cancelled)

Fixes vs the previously deployed version:
  * GPS floats are converted to Decimal before any put/update (was: 500).
  * Missing / empty {id} returns 400 (was: 500 ValidationException).
  * Every incident carries `events[]`, `assigned_patrol_id`, `assigned_officer`,
    `eta_seconds`, and both `lat/lng` + `latitude/longitude`.
"""

import uuid

import rakshak_common as rc

LIVE_STATES = ("active", "dispatched", "reached")
TERMINAL_STATES = ("resolved", "cancelled")

# Every accepted spelling -> the canonical status it means. Anything not listed
# is rejected with a 400; the endpoint used to accept {"status": "banana"}.
_STATUS_ALIASES = {
    "dispatched": "dispatched", "assign": "dispatched", "en_route": "dispatched",
    "reached": "reached", "at_scene": "reached", "atscene": "reached", "arrived": "reached",
    "resolved": "resolved", "resolve": "resolved", "closed": "resolved", "done": "resolved",
    "cancelled": "cancelled", "canceled": "cancelled", "cancel": "cancelled",
}


def _canonical_status(raw):
    return _STATUS_ALIASES.get(str(raw or "").lower().strip())


def _sos_table():
    return rc.table(rc.T_SOS)


def _coords(body):
    return rc.coord(body, "latitude", "lat"), rc.coord(body, "longitude", "lng")


def _enrich(item, now=None):
    """Attach live ETA + patrol position to a stored SOS row for responses."""
    now = now or rc.now_ts()
    out = rc.from_ddb(dict(item))
    pid = out.get("assigned_patrol_id")
    if pid and out.get("status") in ("dispatched", "reached"):
        got = rc.table(rc.T_PATROLS).get_item(Key={"patrol_id": pid}).get("Item")
        if got:
            pv = rc.compute_patrol_view(got, now)
            out["patrol_position"] = pv.get("position")
            out["eta_seconds"] = pv.get("eta_seconds") if out.get("status") == "dispatched" else 0
    return out


# Chennai bounding box — anything outside this is not a Chennai incident and is
# almost certainly a malformed payload rather than a real SOS.
_LAT_RANGE = (12.7, 13.4)
_LNG_RANGE = (79.9, 80.4)


def _validate_create(body, lat, lng):
    """Reject junk payloads before they become permanent incident rows.

    Previously an empty body, malformed JSON, or latitude:"abc" all returned 201
    and created an undeletable junk incident in the live feed.
    """
    if not isinstance(body, dict) or not body:
        return "request body must be a non-empty JSON object"
    # rc.coord() returns None both for "absent" and for "present but unparseable".
    # Only the second case is an error, so check the raw fields.
    for name, alias, parsed, rng in (
        ("latitude", "lat", lat, _LAT_RANGE),
        ("longitude", "lng", lng, _LNG_RANGE),
    ):
        raw = body.get(name, body.get(alias))
        if raw is None:
            continue  # coordinates are optional — incident is queued without dispatch
        if parsed is None:
            return f"{name} must be a number, got {raw!r}"
        if not (rng[0] <= parsed <= rng[1]):
            return f"{name} {parsed} is outside the Chennai service area {rng}"
    return None


def _create(event):
    body = rc.parse_body(event)
    lat, lng = _coords(body)
    err = _validate_create(body, lat, lng)
    if err:
        return rc.bad_request(err)
    sos_id = "SOS-" + uuid.uuid4().hex[:8].upper()
    ts = rc.now_iso()

    pincode = str(body.get("pincode") or body.get("zone_id") or "")
    if not pincode and lat is not None and lng is not None:
        pincode = rc.zone_for_point(lat, lng)
    zname = body.get("zone_name") or (rc.zone_name(pincode) if pincode else "Unknown")

    item = {
        "sos_id": sos_id,
        "status": "active",
        "created_at": ts,
        "triggered_at": ts,
        "updated_at": ts,
        "user_id": body.get("user_id") or body.get("userId") or "anonymous",
        "username": body.get("username") or body.get("userName") or "Citizen",
        "pincode": pincode,
        "zone_name": zname,
        "risk_level": (body.get("risk_level") or "HIGH"),
        "battery": body.get("battery", body.get("battery_percentage")),
        "network": body.get("network", body.get("network_type")),
        "events": [],
    }
    if lat is not None and lng is not None:
        item.update(lat=lat, lng=lng, latitude=lat, longitude=lng)
    # carry any extra caller fields without clobbering managed ones
    for k, v in body.items():
        if k not in item and k not in ("lat", "lng", "latitude", "longitude"):
            item[k] = v

    events = [rc.make_event(rc.EV_CREATED, f"SOS raised in {zname}", pincode=pincode)]

    assigned = None
    if lat is not None and lng is not None:
        try:
            assigned = rc.assign_nearest_patrol(sos_id, lat, lng)
        except Exception as e:  # assignment must never block incident creation
            events.append(rc.make_event(rc.EV_AWAITING, f"auto-assign error: {e}"))

    if assigned:
        item["status"] = "dispatched"
        item["assigned_patrol_id"] = assigned["patrol_id"]
        item["assigned_officer"] = assigned.get("officer")
        item["assigned_vehicle"] = assigned.get("vehicle")
        item["eta_seconds"] = int(assigned.get("eta_seconds") or 0)
        item["dispatched_at"] = ts
        events.append(rc.make_event(
            rc.EV_ASSIGNED,
            f"{assigned['name']} ({assigned.get('vehicle')}) assigned",
            patrol_id=assigned["patrol_id"]))
        events.append(rc.make_event(
            rc.EV_EN_ROUTE,
            f"ETA ~{int(assigned.get('eta_seconds') or 0)}s",
            patrol_id=assigned["patrol_id"]))
    else:
        item["assigned_patrol_id"] = None
        item["eta_seconds"] = None
        events.append(rc.make_event(rc.EV_AWAITING, "No free patrol — queued"))

    item["events"] = events
    _sos_table().put_item(Item=rc.to_ddb(item))

    return rc.created({
        "sos_id": sos_id,
        "status": item["status"],
        "assigned_patrol_id": item.get("assigned_patrol_id"),
        "assigned_officer": item.get("assigned_officer"),
        "eta_seconds": item.get("eta_seconds"),
        "zone_name": zname,
        "pincode": pincode,
        "created_at": ts,
    })


def _list(event):
    qs = rc.query_params(event)
    user_id = qs.get("user_id") or qs.get("userId")
    now = rc.now_ts()
    rows = rc.scan_all(_sos_table())
    out = []
    for it in rows:
        if it.get("status") not in LIVE_STATES:
            continue
        if user_id and str(it.get("user_id")) != str(user_id):
            continue
        out.append(_enrich(it, now))
    out.sort(key=lambda r: r.get("created_at", ""), reverse=True)
    return rc.ok(out)


def _dispatch(event, sos_id):
    if not sos_id:
        return rc.bad_request("sos_id required")
    got = _sos_table().get_item(Key={"sos_id": sos_id}).get("Item")
    if not got:
        return rc.not_found("sos not found")
    if got.get("assigned_patrol_id"):
        return rc.ok({"sos_id": sos_id, "status": got.get("status"),
                      "assigned_patrol_id": got.get("assigned_patrol_id"),
                      "note": "already dispatched"})
    lat = rc.coord(got, "lat", "latitude")
    lng = rc.coord(got, "lng", "longitude")
    if lat is None or lng is None:
        return rc.bad_request("incident has no coordinates to dispatch to")
    assigned = rc.assign_nearest_patrol(sos_id, lat, lng)
    if not assigned:
        return rc.ok({"sos_id": sos_id, "status": got.get("status"),
                      "assigned_patrol_id": None, "note": "no free patrol"})
    ts = rc.now_iso()
    _sos_table().update_item(
        Key={"sos_id": sos_id},
        UpdateExpression=("SET #s = :d, assigned_patrol_id = :p, assigned_officer = :o, "
                          "assigned_vehicle = :v, eta_seconds = :e, dispatched_at = :t, updated_at = :t"),
        ExpressionAttributeNames={"#s": "status"},
        ExpressionAttributeValues=rc.to_ddb({
            ":d": "dispatched", ":p": assigned["patrol_id"], ":o": assigned.get("officer"),
            ":v": assigned.get("vehicle"), ":e": int(assigned.get("eta_seconds") or 0), ":t": ts}),
    )
    rc.append_events(_sos_table(), {"sos_id": sos_id}, [
        rc.make_event(rc.EV_ASSIGNED, f"{assigned['name']} assigned", patrol_id=assigned["patrol_id"]),
        rc.make_event(rc.EV_EN_ROUTE, f"ETA ~{int(assigned.get('eta_seconds') or 0)}s",
                      patrol_id=assigned["patrol_id"]),
    ])
    return rc.ok({"sos_id": sos_id, "status": "dispatched",
                  "assigned_patrol_id": assigned["patrol_id"],
                  "eta_seconds": assigned.get("eta_seconds")})


def _resolve(event, sos_id):
    if not sos_id:
        return rc.bad_request("sos_id required")
    got = _sos_table().get_item(Key={"sos_id": sos_id}).get("Item")
    if not got:
        return rc.not_found("sos not found")
    ts = rc.now_iso()
    _sos_table().update_item(
        Key={"sos_id": sos_id},
        UpdateExpression="SET #s = :r, resolved_at = :t, updated_at = :t, eta_seconds = :z",
        ExpressionAttributeNames={"#s": "status"},
        ExpressionAttributeValues={":r": "resolved", ":t": ts, ":z": 0},
    )
    pid = got.get("assigned_patrol_id")
    if pid:
        try:
            rc.release_patrol(pid)
        except Exception:
            pass
    rc.append_events(_sos_table(), {"sos_id": sos_id},
                     [rc.make_event(rc.EV_RESOLVED, "Incident resolved", patrol_id=pid)])
    return rc.ok({"sos_id": sos_id, "status": "resolved"})


def _cancel(event):
    body = rc.parse_body(event)
    sos_id = body.get("sos_id")
    if not sos_id:
        return rc.bad_request("sos_id required")
    got = _sos_table().get_item(Key={"sos_id": sos_id}).get("Item")
    if not got:
        return rc.not_found("sos not found")
    ts = rc.now_iso()
    _sos_table().update_item(
        Key={"sos_id": sos_id},
        UpdateExpression="SET #s = :c, cancelled_at = :t, updated_at = :t, user_phone = :ph, eta_seconds = :z",
        ExpressionAttributeNames={"#s": "status"},
        ExpressionAttributeValues={":c": "cancelled", ":t": ts,
                                   ":ph": body.get("user_phone", ""), ":z": 0},
    )
    pid = got.get("assigned_patrol_id")
    if pid:
        try:
            rc.release_patrol(pid)
        except Exception:
            pass
    rc.append_events(_sos_table(), {"sos_id": sos_id},
                     [rc.make_event(rc.EV_CANCELLED, "Citizen cancelled", patrol_id=pid)])
    return rc.ok({"message": "SOS cancelled", "sos_id": sos_id})


def _get_one(event, sos_id):
    """GET /incident/{id} — single incident, enriched with live ETA/patrol position."""
    if not sos_id:
        return rc.bad_request("id required")
    got = _sos_table().get_item(Key={"sos_id": sos_id}).get("Item")
    if not got:
        return rc.not_found("incident not found")
    return rc.ok(_enrich(got))


def _get_eta(event, sos_id):
    """GET /incident/{id}/eta — ETA + live patrol position only, for a tight poll."""
    if not sos_id:
        return rc.bad_request("id required")
    got = _sos_table().get_item(Key={"sos_id": sos_id}).get("Item")
    if not got:
        return rc.not_found("incident not found")
    out = _enrich(got)
    return rc.ok({
        "sos_id": out.get("sos_id"), "status": out.get("status"),
        "assigned_patrol_id": out.get("assigned_patrol_id"),
        "eta_seconds": out.get("eta_seconds"),
        "distance_m": out.get("distance_m"),
        "patrol_position": out.get("patrol_position"),
    })


def _active(event):
    qs = rc.query_params(event)
    want_patrol = qs.get("patrol_id")
    try:
        olat = float(qs.get("officer_lat", 13.06))
        olng = float(qs.get("officer_lng", 80.27))
    except (TypeError, ValueError):
        olat, olng = 13.06, 80.27

    now = rc.now_ts()
    rows = rc.scan_all(_sos_table())
    out = []
    for it in rows:
        if it.get("status") not in LIVE_STATES:
            continue
        if want_patrol and str(it.get("assigned_patrol_id")) != str(want_patrol):
            continue
        r = rc.from_ddb(dict(it))
        lat = rc.coord(r, "lat", "latitude") or 0.0
        lng = rc.coord(r, "lng", "longitude") or 0.0
        r["lat"], r["lng"] = lat, lng
        r["distance_km"] = round(rc.haversine_km(olat, olng, lat, lng), 2) if (lat or lng) else 9999.0
        r["area_name"] = r.get("zone_name") or rc.zone_name(r.get("pincode"))

        pid = r.get("assigned_patrol_id")
        if pid:
            got = rc.table(rc.T_PATROLS).get_item(Key={"patrol_id": pid}).get("Item")
            if got:
                pv = rc.compute_patrol_view(got, now)
                r["patrol_position"] = pv.get("position")
                r["patrol_status"] = pv.get("status")
                r["eta_seconds"] = pv.get("eta_seconds") if r.get("status") == "dispatched" else 0
        out.append(r)

    out.sort(key=lambda x: x.get("distance_km", 9999.0))
    return rc.ok(out[:50])


def _set_status(event, sos_id):
    if not sos_id:
        return rc.bad_request("sos_id required")
    body = rc.parse_body(event)
    new_status = (body.get("status") or "").lower().strip()
    officer_id = body.get("officer_id", "")
    patrol_id = body.get("patrol_id")

    got = _sos_table().get_item(Key={"sos_id": sos_id}).get("Item")
    if not got:
        return rc.not_found("sos not found")

    canonical = _canonical_status(new_status)
    if canonical is None:
        return rc.bad_request(
            f"status must be one of {sorted(set(_STATUS_ALIASES.values()))}, got {new_status!r}")
    current = str(got.get("status") or "").lower()
    if current in TERMINAL_STATES and canonical not in TERMINAL_STATES:
        return rc.bad_request(
            f"incident is {current}; cannot move back to {canonical}")

    patrol_id = patrol_id or got.get("assigned_patrol_id")
    ts = rc.now_iso()
    notes = str(body.get("notes") or "").strip()[:500]

    # ---- dispatched: assign a patrol if the incident has none ----
    if canonical == "dispatched":
        if not patrol_id:
            lat = rc.coord(got, "lat", "latitude")
            lng = rc.coord(got, "lng", "longitude")
            if lat is None or lng is None:
                return rc.bad_request("incident has no coordinates")
            assigned = rc.assign_nearest_patrol(sos_id, lat, lng)
            if not assigned:
                return rc.ok({"sos_id": sos_id, "status": got.get("status"),
                              "assigned_patrol_id": None, "note": "no free patrol"})
            patrol_id = assigned["patrol_id"]
            _sos_table().update_item(
                Key={"sos_id": sos_id},
                UpdateExpression=("SET #s=:d, assigned_patrol_id=:p, assigned_officer=:o, "
                                  "assigned_vehicle=:v, eta_seconds=:e, dispatched_at=:t, updated_at=:t"),
                ExpressionAttributeNames={"#s": "status"},
                ExpressionAttributeValues=rc.to_ddb({
                    ":d": "dispatched", ":p": patrol_id, ":o": assigned.get("officer"),
                    ":v": assigned.get("vehicle"), ":e": int(assigned.get("eta_seconds") or 0), ":t": ts}),
            )
            rc.append_events(_sos_table(), {"sos_id": sos_id}, [
                rc.make_event(rc.EV_ASSIGNED, f"{assigned['name']} assigned", patrol_id=patrol_id),
                rc.make_event(rc.EV_EN_ROUTE, f"ETA ~{int(assigned.get('eta_seconds') or 0)}s", patrol_id=patrol_id),
            ])
        return rc.ok({"sos_id": sos_id, "status": "dispatched", "assigned_patrol_id": patrol_id})

    # ---- reached ----
    if canonical == "reached":
        upd = "SET #s=:r, reached_at=:t, updated_at=:t, eta_seconds=:z"
        vals = {":r": "reached", ":t": ts, ":z": 0}
        if officer_id:
            upd += ", officer_id=:o"; vals[":o"] = officer_id
        if notes:
            upd += ", notes=:n"; vals[":n"] = notes
        _sos_table().update_item(Key={"sos_id": sos_id}, UpdateExpression=upd,
                                 ExpressionAttributeNames={"#s": "status"},
                                 ExpressionAttributeValues=rc.to_ddb(vals))
        if patrol_id:
            try:
                rc.table(rc.T_PATROLS).update_item(
                    Key={"patrol_id": patrol_id},
                    UpdateExpression="SET #s=:sc, updated_at=:t",
                    ExpressionAttributeNames={"#s": "status"},
                    ExpressionAttributeValues={":sc": rc.S_SCENE, ":t": ts})
            except Exception:
                pass
        rc.append_events(_sos_table(), {"sos_id": sos_id},
                         [rc.make_event(rc.EV_REACHED, notes or "Officer on scene", patrol_id=patrol_id)])
        return rc.ok({"sos_id": sos_id, "status": "reached", "assigned_patrol_id": patrol_id})

    # ---- resolved ----
    if canonical == "resolved":
        upd = "SET #s=:r, resolved_at=:t, updated_at=:t, eta_seconds=:z"
        vals = {":r": "resolved", ":t": ts, ":z": 0}
        if officer_id:
            upd += ", officer_id=:o"; vals[":o"] = officer_id
        if notes:
            upd += ", notes=:n"; vals[":n"] = notes
        _sos_table().update_item(Key={"sos_id": sos_id}, UpdateExpression=upd,
                                 ExpressionAttributeNames={"#s": "status"},
                                 ExpressionAttributeValues=rc.to_ddb(vals))
        if patrol_id:
            try:
                rc.release_patrol(patrol_id)
            except Exception:
                pass
        rc.append_events(_sos_table(), {"sos_id": sos_id},
                         [rc.make_event(rc.EV_RESOLVED, notes or "Incident resolved", patrol_id=patrol_id)])
        return rc.ok({"sos_id": sos_id, "status": "resolved", "assigned_patrol_id": patrol_id})

    # ---- cancelled ----
    upd = "SET #s=:r, cancelled_at=:t, updated_at=:t, eta_seconds=:z"
    vals = {":r": "cancelled", ":t": ts, ":z": 0}
    if notes:
        upd += ", notes=:n"; vals[":n"] = notes
    _sos_table().update_item(Key={"sos_id": sos_id}, UpdateExpression=upd,
                             ExpressionAttributeNames={"#s": "status"},
                             ExpressionAttributeValues=rc.to_ddb(vals))
    if patrol_id:
        try:
            rc.release_patrol(patrol_id)
        except Exception:
            pass
    rc.append_events(_sos_table(), {"sos_id": sos_id},
                     [rc.make_event(rc.EV_CANCELLED, notes or "Incident cancelled",
                                    patrol_id=patrol_id)])
    return rc.ok({"sos_id": sos_id, "status": "cancelled", "assigned_patrol_id": patrol_id})


def _accept(event, sos_id):
    """PATCH /incident/{id}/accept — additive acknowledgment.

    The backend already auto-dispatches on creation, so there is no separate
    "accept vs reject" decision to make; this route exists for the frozen
    contract and records *who* acknowledged the dispatch without changing the
    incident's status or touching the assigned patrol.
    """
    if not sos_id:
        return rc.bad_request("id required")
    got = _sos_table().get_item(Key={"sos_id": sos_id}).get("Item")
    if not got:
        return rc.not_found("incident not found")
    body = rc.parse_body(event)
    officer_id = str(body.get("officer_id") or body.get("patrol_id") or "").strip()
    ts = rc.now_iso()
    upd = "SET accepted_at = :t, updated_at = :t"
    vals = {":t": ts}
    if officer_id:
        upd += ", accepted_by = :o"
        vals[":o"] = officer_id
    _sos_table().update_item(Key={"sos_id": sos_id}, UpdateExpression=upd,
                             ExpressionAttributeValues=vals)
    rc.append_events(_sos_table(), {"sos_id": sos_id},
                     [rc.make_event("Accepted", f"Acknowledged by {officer_id or 'officer'}",
                                    patrol_id=got.get("assigned_patrol_id"))])
    return rc.ok({"sos_id": sos_id, "status": got.get("status"),
                  "assigned_patrol_id": got.get("assigned_patrol_id"), "accepted_at": ts})


def _incident_id_from(path, suffix):
    return path.split("/incident/")[-1].split(suffix)[0].strip("/")


def lambda_handler(event, context):
    if isinstance(event, dict) and event.get("warm"):
        # EventBridge keep-warm ping (see deploy/deploy.py ensure_observability) —
        # skip routing entirely so it never touches DynamoDB.
        return {"warm": True}
    if rc.is_options(event):
        return rc.preflight()
    method = rc.http_method(event)
    path = rc.http_path(event)
    pp = rc.path_params(event)
    try:
        # ── Frozen-contract paths (additive aliases of the routes below) ──────
        if method == "POST" and path.endswith("/sos") and not path.endswith("/sos/live"):
            return _create(event)
        if method == "GET" and path.endswith("/eta"):
            sid = pp.get("id") or path.split("/incident/")[-1].split("/eta")[0].strip("/")
            return _get_eta(event, sid)
        if method == "PATCH" and "/incident/" in path and path.endswith("/accept"):
            sid = pp.get("id") or _incident_id_from(path, "/accept")
            return _accept(event, sid)
        if method == "PATCH" and "/incident/" in path and path.endswith("/resolve"):
            sid = pp.get("id") or _incident_id_from(path, "/resolve")
            body = rc.parse_body(event)
            body["status"] = "resolved"
            return _set_status({**event, "body": body}, sid)
        if method == "PATCH" and "/incident/" in path and path.endswith("/status"):
            sid = pp.get("id") or _incident_id_from(path, "/status")
            return _set_status(event, sid)
        if method == "GET" and "/incident/" in path:
            sid = pp.get("id") or path.split("/incident/")[-1].strip("/")
            return _get_one(event, sid)
        if method == "GET" and path.endswith("/incidents/active"):
            return _active(event)

        # ── Existing routes (unchanged) ────────────────────────────────────────
        if method == "POST" and path.endswith("/sos/live"):
            return _create(event)
        if method == "GET" and path.endswith("/sos/live"):
            return _list(event)
        if method == "POST" and "/sos/dispatch/" in path:
            return _dispatch(event, pp.get("id") or path.split("/sos/dispatch/")[-1].strip("/"))
        if method == "PATCH" and "/sos/resolve/" in path:
            return _resolve(event, pp.get("id") or path.split("/sos/resolve/")[-1].strip("/"))
        if method == "POST" and path.endswith("/sos/cancelled"):
            return _cancel(event)
        if method == "GET" and path.endswith("/police/sos/active"):
            return _active(event)
        if method == "PATCH" and "/police/sos/" in path and path.endswith("/status"):
            sid = pp.get("sos_id") or path.split("/police/sos/")[-1].split("/status")[0].strip("/")
            return _set_status(event, sid)
        return rc.not_found("route not found")
    except Exception as e:  # pragma: no cover
        return rc.server_error(e)
