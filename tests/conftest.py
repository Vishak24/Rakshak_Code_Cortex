"""
In-memory DynamoDB double — just enough of the Table API for the Rakshak-SIH
handlers (no moto available in this environment).

Supports: put_item, get_item, update_item (SET / REMOVE / list_append /
if_not_exists, ConditionExpression with '=', attribute_exists,
attribute_not_exists joined by AND), scan (+ a minimal Attr(...).eq()
FilterExpression), ExpressionAttributeNames / Values.
"""

import os
import re
import sys
from decimal import Decimal

import pytest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHARED = os.path.join(ROOT, "backend", "lambdas", "_shared")
for p in (SHARED,):
    if p not in sys.path:
        sys.path.insert(0, p)


@pytest.fixture(autouse=True)
def _offline_ml(monkeypatch):
    """Force predict_safety() down the deterministic baseline path in every test.

    Without this, a machine that happens to have live AWS credentials + the
    real `rakshak-risk-endpoint` makes tests non-deterministic (a test asserting
    `source == "baseline"` would see `"sagemaker"`).
    """
    import rakshak_common as rc
    monkeypatch.setattr(rc, "sm_runtime",
                        lambda: (_ for _ in ()).throw(RuntimeError("no sagemaker (test)")))
    monkeypatch.setattr(rc, "_load_s3_booster",
                        lambda: (_ for _ in ()).throw(RuntimeError("no s3 model (test)")))
    # circuit-breaker state and the cached booster are module-level (persist across
    # warm Lambda invocations by design) — reset them per test for isolation.
    monkeypatch.setattr(rc, "_TIER_FAIL_UNTIL", {})
    monkeypatch.setattr(rc, "_S3_BOOSTER", None, raising=False)


class ConditionalCheckFailedException(Exception):
    pass


def _split_top_commas(s):
    out, depth, cur = [], 0, ""
    for ch in s:
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
        if ch == "," and depth == 0:
            out.append(cur)
            cur = ""
        else:
            cur += ch
    if cur.strip():
        out.append(cur)
    return [x.strip() for x in out]


class FakeTable:
    def __init__(self, name, key_names):
        self.name = name
        self.key_names = key_names  # list[str]
        self.items = {}

    # ---- key helpers ----
    def _k(self, key):
        return tuple(str(key[k]) for k in self.key_names)

    # ---- API ----
    def put_item(self, Item=None, **kw):
        Item = Item or kw.get("Item")
        self.items[self._k(Item)] = dict(Item)
        return {}

    def get_item(self, Key=None, **kw):
        Key = Key or kw.get("Key")
        it = self.items.get(self._k(Key))
        return {"Item": dict(it)} if it else {}

    def scan(self, **kw):
        rows = [dict(v) for v in self.items.values()]
        fe = kw.get("FilterExpression")
        if fe is not None:
            rows = [r for r in rows if _eval_filter(fe, r)]
        if kw.get("Select") == "COUNT":
            return {"Count": len(rows)}
        return {"Items": rows}

    def update_item(self, Key=None, UpdateExpression="", ConditionExpression=None,
                    ExpressionAttributeNames=None, ExpressionAttributeValues=None, **kw):
        Key = Key or kw.get("Key")
        names = ExpressionAttributeNames or {}
        vals = ExpressionAttributeValues or {}
        k = self._k(Key)
        item = self.items.get(k, dict(Key))

        if ConditionExpression is not None:
            if not _eval_condition_str(ConditionExpression, item, names, vals):
                raise ConditionalCheckFailedException(
                    "The conditional request failed (ConditionalCheckFailedException)")

        expr = UpdateExpression.strip()
        set_part, rem_part = expr, ""
        m = re.search(r"\bREMOVE\b", expr, re.I)
        if m:
            set_part, rem_part = expr[:m.start()], expr[m.end():]
        m2 = re.match(r"\s*SET\s+(.*)", set_part, re.I | re.S)
        if m2:
            for assign in _split_top_commas(m2.group(1)):
                lhs, rhs = assign.split("=", 1)
                lhs = _resolve_name(lhs.strip(), names)
                item[lhs] = _eval_rhs(rhs.strip(), item, names, vals)
        for attr in [a.strip() for a in rem_part.split(",") if a.strip()]:
            item.pop(_resolve_name(attr, names), None)

        self.items[k] = item
        return {"Attributes": dict(item)}


def _resolve_name(tok, names):
    tok = tok.strip()
    return names.get(tok, tok) if tok.startswith("#") else tok


def _eval_rhs(rhs, item, names, vals):
    rhs = rhs.strip()
    m = re.match(r"list_append\(\s*if_not_exists\(\s*([#\w]+)\s*,\s*(:\w+)\s*\)\s*,\s*(:\w+)\s*\)$", rhs)
    if m:
        base_attr = _resolve_name(m.group(1), names)
        cur = item.get(base_attr, vals.get(m.group(2), []))
        return list(cur) + list(vals.get(m.group(3), []))
    m = re.match(r"if_not_exists\(\s*([#\w]+)\s*,\s*(:\w+)\s*\)$", rhs)
    if m:
        base_attr = _resolve_name(m.group(1), names)
        return item.get(base_attr, vals.get(m.group(2)))
    if rhs.startswith(":"):
        return vals.get(rhs)
    return rhs  # bare literal


def _eval_condition_str(cond, item, names, vals):
    cond = cond.strip()
    for clause in re.split(r"\s+AND\s+", cond, flags=re.I):
        clause = clause.strip()
        m = re.match(r"attribute_not_exists\(\s*([#\w]+)\s*\)$", clause)
        if m:
            if _resolve_name(m.group(1), names) in item:
                return False
            continue
        m = re.match(r"attribute_exists\(\s*([#\w]+)\s*\)$", clause)
        if m:
            if _resolve_name(m.group(1), names) not in item:
                return False
            continue
        m = re.match(r"([#\w]+)\s*=\s*(:\w+)$", clause)
        if m:
            lhs = _resolve_name(m.group(1), names)
            if item.get(lhs) != vals.get(m.group(2)):
                return False
            continue
        raise AssertionError(f"unsupported condition clause in test double: {clause!r}")
    return True


def _eval_filter(fe, row):
    # supports Attr('x').eq(v)  and  Attr('x').eq(v) via ConditionBase
    try:
        op = fe.get_expression()["operator"]
        vals_ = fe.get_expression()["values"]
        name = vals_[0].name
        target = vals_[1]
        if op == "=":
            return str(row.get(name)) == str(target)
    except Exception:
        pass
    return True


class FakeDDB:
    def __init__(self, tables):
        self._tables = tables

    def Table(self, name):
        return self._tables[name]


@pytest.fixture
def ddb(monkeypatch):
    import rakshak_common as rc
    tables = {
        rc.T_PATROLS: FakeTable(rc.T_PATROLS, ["patrol_id"]),
        rc.T_SOS: FakeTable(rc.T_SOS, ["sos_id"]),
        rc.T_USERS: FakeTable(rc.T_USERS, ["user_id"]),
        rc.T_INCIDENTS: FakeTable(rc.T_INCIDENTS, ["incident_id", "created_at"]),
    }
    fake = FakeDDB(tables)
    monkeypatch.setattr(rc, "_ddb", fake, raising=False)
    monkeypatch.setattr(rc, "ddb", lambda: fake)
    # force ML resolver down the deterministic baseline path in tests
    monkeypatch.setattr(rc, "sm_runtime", lambda: (_ for _ in ()).throw(RuntimeError("no sagemaker")))
    monkeypatch.setattr(rc, "_load_s3_booster", lambda: (_ for _ in ()).throw(RuntimeError("no model")))
    monkeypatch.setattr(rc, "_TIER_FAIL_UNTIL", {})
    monkeypatch.setattr(rc, "_S3_BOOSTER", None, raising=False)
    return tables


def seed_patrols(tables, n=20):
    import rakshak_common as rc
    now = rc.now_ts()
    t = tables[rc.T_PATROLS]
    for i, u in enumerate(rc.PATROL_UNITS[:n]):
        t.put_item(Item=rc.to_ddb({
            "patrol_id": u["patrol_id"], "name": u["name"], "officer": u["officer"],
            "vehicle": u["vehicle"], "status": rc.S_PATROL,
            "cycle_start_ts": now - i * 30, "route": None,
            "zone": rc.unit_home_pincode(u), "updated_at": rc.now_iso(),
        }))


def http_event(method, path, body=None, path_params=None, qs=None):
    import json as _j
    return {
        "requestContext": {"http": {"method": method}},
        "rawPath": path,
        "pathParameters": path_params or {},
        "queryStringParameters": qs or {},
        "body": _j.dumps(body) if body is not None else None,
    }
