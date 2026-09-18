#!/usr/bin/env python3
"""
seed_demo_state.py — put the demo into a known-good starting state.

  python3 seed/seed_demo_state.py                    # dry run (prints, writes nothing)
  python3 seed/seed_demo_state.py --apply            # write patrols + history
  python3 seed/seed_demo_state.py --clear-active     # dry-run the stale-incident purge
  python3 seed/seed_demo_state.py --apply --clear-active   # full reset for demo day

What it writes (all put_item — no table creation, no deletes):
  rakshak-patrols      : 20 units P001..P020, status=Patrolling, staggered along
                         their routes (overwrites the 3 legacy P001..P003 rows).
  rakshak-sos-alerts   : ~9 historical incidents (resolved / cancelled) spread
                         over the last 6 days, each with a full events[] timeline
                         and an assigned_patrol_id. NO active incidents -> the
                         live feed starts empty.

  --clear-active     : deletes every left-over active/dispatched/reached row
                       (legacy SOS-001/002/003 seeds, rehearsal and audit
                       incidents) and releases any patrol still holding one.
                       Deleting rather than resolving keeps `resolved_today`
                       honest — a purged rehearsal incident is not a resolution
                       the team should get credit for on the dashboard.
                       Resolved / cancelled history is never touched.

Safety:
  * profile  = agent-toolkit   (never the default profile)
  * region   = ap-south-1
  * aborts unless STS account == 468704514492
"""

import argparse
import os
import random
import sys
import time
import uuid
from datetime import datetime, timedelta, timezone

import boto3

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "backend", "lambdas", "_shared"))
import rakshak_common as rc  # noqa: E402

PROFILE = "agent-toolkit"
REGION = "ap-south-1"
EXPECTED_ACCOUNT = "468704514492"

OFFICERS = [u["officer"] for u in rc.PATROL_UNITS]
HIST_ZONES = ["600001", "600011", "600020", "600007", "600058", "600021",
              "600017", "600034", "600042", "600004", "600012"]
INCIDENT_KINDS = ["Harassment reported", "Suspicious individual", "Chain snatching",
                  "Stalking complaint", "Public nuisance", "Eve-teasing", "Theft in progress"]


def _sess():
    return boto3.Session(profile_name=PROFILE, region_name=REGION)


def _guard(sess):
    ident = sess.client("sts").get_caller_identity()
    if ident["Account"] != EXPECTED_ACCOUNT:
        sys.exit(f"ABORT: account {ident['Account']} != expected {EXPECTED_ACCOUNT}")
    print(f"  STS ok — account {ident['Account']}  ({ident['Arn']})")


def build_patrols(now):
    rows = []
    for i, u in enumerate(rc.PATROL_UNITS):
        rows.append({
            "patrol_id": u["patrol_id"],
            "name": u["name"],
            "officer": u["officer"],
            "vehicle": u["vehicle"],
            "status": rc.S_PATROL,
            # spread units around their loops so they don't all start at waypoint 0
            "cycle_start_ts": now - (i * 47) - random.randint(0, 400),
            "zone": rc.unit_home_pincode(u),
            "zone_name": rc.zone_name(rc.unit_home_pincode(u)),
            "updated_at": rc.now_iso(),
        })
    return rows


def build_history(now, n=9):
    rows = []
    for k in range(n):
        pin = HIST_ZONES[k % len(HIST_ZONES)]
        lat, lng = rc.ZONE_COORDS.get(pin, (13.08, 80.27))
        lat += random.uniform(-0.004, 0.004)
        lng += random.uniform(-0.004, 0.004)
        created = datetime.now(timezone.utc) - timedelta(
            days=random.randint(1, 6), hours=random.randint(0, 23), minutes=random.randint(0, 59))
        assigned = created + timedelta(seconds=random.randint(20, 90))
        reached = assigned + timedelta(minutes=random.randint(4, 12))
        closed = reached + timedelta(minutes=random.randint(5, 25))
        cancelled = random.random() < 0.22
        pid = rc.PATROL_UNITS[k % len(rc.PATROL_UNITS)]["patrol_id"]
        officer = rc.PATROL_UNIT_BY_ID[pid]["officer"]
        iso = lambda d: d.isoformat().replace("+00:00", "Z")

        events = [
            {"type": rc.EV_CREATED, "ts": iso(created), "detail": INCIDENT_KINDS[k % len(INCIDENT_KINDS)], "pincode": pin},
            {"type": rc.EV_ASSIGNED, "ts": iso(assigned), "detail": f"{rc.PATROL_UNIT_BY_ID[pid]['name']} assigned", "patrol_id": pid},
            {"type": rc.EV_EN_ROUTE, "ts": iso(assigned), "detail": "Unit en route", "patrol_id": pid},
        ]
        row = {
            "sos_id": "SOS-" + uuid.uuid4().hex[:8].upper(),
            "created_at": iso(created),
            "triggered_at": iso(created),
            "updated_at": iso(cancelled and assigned or closed),
            "user_id": f"citizen-{random.randint(100, 999)}",
            "username": random.choice(["Asha", "Divya", "Meena", "Priya", "Sana", "Kavya", "Nithya"]),
            "pincode": pin,
            "zone_name": rc.zone_name(pin),
            "lat": lat, "lng": lng, "latitude": lat, "longitude": lng,
            "risk_level": random.choice(["HIGH", "HIGH", "MEDIUM"]),
            "assigned_patrol_id": pid,
            "assigned_officer": officer,
            "dispatched_at": iso(assigned),
            "eta_seconds": 0,
        }
        if cancelled:
            row["status"] = "cancelled"
            row["cancelled_at"] = iso(assigned + timedelta(minutes=random.randint(1, 4)))
            events.append({"type": rc.EV_CANCELLED, "ts": row["cancelled_at"], "detail": "Citizen marked safe", "patrol_id": pid})
        else:
            row["status"] = "resolved"
            row["reached_at"] = iso(reached)
            row["resolved_at"] = iso(closed)
            events.append({"type": rc.EV_REACHED, "ts": iso(reached), "detail": "Officer on scene", "patrol_id": pid})
            events.append({"type": rc.EV_RESOLVED, "ts": iso(closed), "detail": "Incident resolved", "patrol_id": pid})
        row["events"] = events
        rows.append(row)
    return rows


LIVE_STATES = ("active", "dispatched", "reached")

# user_id values that only ever come from a health check, a rehearsal, or an
# audit script — never from the citizen app. Rows owned by these are test data.
TEST_USER_IDS = {
    "anonymous", "x", "u1", "u2", "hc", "verify", "test", "citizen-demo",
    "phase1-healthcheck", "pre-demo-cleanup",
}
TEST_USER_PREFIXES = ("audit", "test", "verify", "healthcheck", "phase1", "smoke",
                      "rehearsal", "probe", "warmup", "__")


def _is_test_row(row):
    """True for rehearsal / health-check / legacy-import rows.

    Genuine seeded history is written with a `citizen-NNN` user_id and a full
    events[] timeline; anything else in the table is an artifact of testing.
    """
    uid = str(row.get("user_id") or "").strip().lower()
    if uid in TEST_USER_IDS or uid.startswith(TEST_USER_PREFIXES):
        return True
    # legacy rows imported before the events[] contract existed: no owner, no
    # timeline, so they contribute nothing to analytics but do skew the counters.
    if not uid and not (row.get("events") or []):
        return True
    return False


def purge_test_rows(sess, apply_):
    """Delete rehearsal/health-check/legacy rows, keep the real resolved history."""
    ddb = sess.resource("dynamodb")
    tsos = ddb.Table(rc.T_SOS)

    doomed, kept = [], 0
    kwargs = {}
    while True:
        page = tsos.scan(**kwargs)
        for row in page.get("Items", []):
            if str(row.get("status") or "").lower() in LIVE_STATES:
                continue  # clear_active() owns these
            (doomed.append(row) if _is_test_row(row) else None)
            kept += 0 if _is_test_row(row) else 1
        if "LastEvaluatedKey" not in page:
            break
        kwargs["ExclusiveStartKey"] = page["LastEvaluatedKey"]

    print(f"\n  test/legacy rows to delete : {len(doomed)}")
    for row in doomed:
        print(f"    - {str(row.get('sos_id')):<16} {str(row.get('status')):<10} "
              f"user={str(row.get('user_id'))[:20]:<20} created={str(row.get('created_at'))[:19]}")
    print(f"  genuine history preserved  : {kept}")

    if not apply_:
        print("  (dry run — nothing deleted)")
        return

    for row in doomed:
        tsos.delete_item(Key={"sos_id": row["sos_id"]})
    print(f"  deleted {len(doomed)} test/legacy rows")


def clear_active(sess, apply_):
    """Purge left-over live incidents so the dashboard opens with an empty feed.

    Anything still in active/dispatched/reached when the demo starts is stale by
    definition — the seeded history is all resolved/cancelled. Rows are deleted,
    not resolved, and every patrol they hold is released back to its route.
    """
    ddb = sess.resource("dynamodb")
    tsos = ddb.Table(rc.T_SOS)

    stale, patrol_ids = [], set()
    kwargs = {}
    while True:
        page = tsos.scan(**kwargs)
        for row in page.get("Items", []):
            if str(row.get("status") or "").lower() in LIVE_STATES:
                stale.append(row)
                if row.get("assigned_patrol_id"):
                    patrol_ids.add(str(row["assigned_patrol_id"]))
        if "LastEvaluatedKey" not in page:
            break
        kwargs["ExclusiveStartKey"] = page["LastEvaluatedKey"]

    print(f"\n  stale active incidents : {len(stale)}")
    for row in stale:
        print(f"    - {row.get('sos_id'):<16} {str(row.get('status')):<11} "
              f"{row.get('zone_name') or row.get('pincode') or '?'}  "
              f"created={row.get('created_at')}")
    print(f"  patrols to release     : {len(patrol_ids)} {sorted(patrol_ids) or ''}")

    if not apply_:
        print("  (dry run — nothing deleted)")
        return

    for row in stale:
        tsos.delete_item(Key={"sos_id": row["sos_id"]})
    print(f"  deleted {len(stale)} stale incident rows")

    for pid in sorted(patrol_ids):
        try:
            # release_patrol() clears the real divert/assignment attributes
            # (sos_lat/sos_lng/divert_*) — not the legacy target_lat/target_lng
            # names this used to REMOVE, which were never actually written —
            # and settle_patrol_to_patrolling() resets cycle_start_ts so the
            # unit reappears on its route instead of jumping from a stale
            # position.
            rc.release_patrol(pid)
            rc.settle_patrol_to_patrolling(pid)
        except Exception as e:
            print(f"    ! could not release {pid}: {e}")
    if patrol_ids:
        print(f"  released {len(patrol_ids)} patrols back to Patrolling")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true", help="write to DynamoDB (default: dry run)")
    ap.add_argument("--history", type=int, default=9)
    ap.add_argument("--clear-active", action="store_true",
                    help="delete left-over active/dispatched/reached incidents")
    ap.add_argument("--only-clear", action="store_true",
                    help="run the purge without rewriting patrols/history")
    args = ap.parse_args()

    if args.only_clear:
        sess = _sess()
        _guard(sess)
        clear_active(sess, args.apply)
        purge_test_rows(sess, args.apply)
        return

    now = time.time()
    patrols = build_patrols(now)
    history = build_history(now, args.history)

    print(f"\nRakshak-SIH demo seed  ({'APPLY' if args.apply else 'DRY RUN'})")
    print(f"  rakshak-patrols    : {len(patrols)} units  ({patrols[0]['patrol_id']}..{patrols[-1]['patrol_id']})")
    print(f"  rakshak-sos-alerts : {len(history)} historical incidents "
          f"({sum(1 for r in history if r['status']=='resolved')} resolved, "
          f"{sum(1 for r in history if r['status']=='cancelled')} cancelled)")
    print("  active incidents   : 0  (feed starts empty)")

    if not args.apply:
        print("\n(dry run — nothing written. re-run with --apply)")
        return

    sess = _sess()
    _guard(sess)
    ddb = sess.resource("dynamodb")
    tp, ts_ = ddb.Table(rc.T_PATROLS), ddb.Table(rc.T_SOS)

    with tp.batch_writer() as bw:
        for r in patrols:
            bw.put_item(Item=rc.to_ddb(r))
    print(f"  wrote {len(patrols)} patrol rows")

    with ts_.batch_writer() as bw:
        for r in history:
            bw.put_item(Item=rc.to_ddb(r))
    print(f"  wrote {len(history)} historical SOS rows")

    if args.clear_active:
        clear_active(sess, True)
        purge_test_rows(sess, True)

    print("\ndone.")


if __name__ == "__main__":
    main()
