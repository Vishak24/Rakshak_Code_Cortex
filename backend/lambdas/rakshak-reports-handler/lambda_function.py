"""
rakshak-reports-handler — citizen incident reports (moderation queue).

Routes (unchanged contract):
  POST   /reports/submit
  GET    /reports
  PATCH  /reports/approve/{id}
  PATCH  /reports/reject/{id}

Fix vs previously deployed version:
  * The old handler built its boto3 resource with embedded IAM keys
    (RAKSHAK_AWS_ACCESS_KEY_ID / _SECRET) that are now invalid -> every call 500'd
    with UnrecognizedClientException. This version uses the Lambda execution role
    (via rakshak_common.table), so the embedded keys can be removed from the
    function configuration.
"""

import uuid

from boto3.dynamodb.conditions import Attr

import rakshak_common as rc


def _table():
    return rc.table(rc.T_INCIDENTS)


def _submit(event):
    body = rc.parse_body(event)
    item = {
        "incident_id": str(uuid.uuid4()),
        "created_at": rc.now_iso(),
        "status": "pending",
    }
    item.update({k: v for k, v in body.items() if k not in item})
    _table().put_item(Item=rc.to_ddb(item))
    return rc.created(rc.from_ddb(item))


def _list(event):
    return rc.ok(rc.from_ddb(rc.scan_all(_table())))


def _moderate(event, incident_id, new_status, stamp):
    if not incident_id:
        return rc.bad_request("incident_id required")
    found = _table().scan(FilterExpression=Attr("incident_id").eq(incident_id)).get("Items", [])
    if not found:
        return rc.not_found("report not found")
    row = found[0]
    _table().update_item(
        Key={"incident_id": incident_id, "created_at": row["created_at"]},
        UpdateExpression=f"SET #s = :s, {stamp} = :t",
        ExpressionAttributeNames={"#s": "status"},
        ExpressionAttributeValues={":s": new_status, ":t": rc.now_iso()},
    )
    return rc.ok({"incident_id": incident_id, "status": new_status})


def lambda_handler(event, context):
    if rc.is_options(event):
        return rc.preflight()
    method = rc.http_method(event)
    path = rc.http_path(event)
    pp = rc.path_params(event)
    try:
        if method == "POST" and path.endswith("/reports/submit"):
            return _submit(event)
        if method == "PATCH" and "/reports/approve/" in path:
            return _moderate(event, pp.get("id") or path.split("/reports/approve/")[-1].strip("/"),
                             "approved", "approved_at")
        if method == "PATCH" and "/reports/reject/" in path:
            return _moderate(event, pp.get("id") or path.split("/reports/reject/")[-1].strip("/"),
                             "rejected", "rejected_at")
        if method == "GET":
            return _list(event)
        return rc.not_found("route not found")
    except Exception as e:  # pragma: no cover
        return rc.server_error(e)
