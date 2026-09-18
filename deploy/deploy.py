#!/usr/bin/env python3
"""
deploy.py — idempotent deploy of the Rakshak-SIH backend to AWS.

    python3 deploy/deploy.py                  # code + config + routes + permissions + log retention
    python3 deploy/deploy.py --layer           # also rebuild/publish the ML layer (numpy+scipy+xgboost-cpu)
    python3 deploy/deploy.py --create-infra    # also create IAM role / tables / GSI / S3 bucket if missing
    python3 deploy/deploy.py --dry-run         # print what would change; make no AWS calls that mutate

Safe to run twice: every step checks current state first (CodeSha256, route
key, attached layer ARN, log-group retention, GSI/table existence, alarm
name) and only calls a mutating API when something is actually different.

Does NOT create the HTTP API itself if API_ID doesn't already exist under
that name — an API Gateway id is AWS-assigned and can't be chosen or
reproduced. On a genuinely empty account, pass --create-infra; the script
creates a new HTTP API, prints its id/base-URL, and you must update
API_BASE_URL in the three frontend apps to match (the id `aksdwfbnn5` this
repo defaults to is specific to the account this was built against).
"""
import argparse
import base64
import hashlib
import json
import os
import subprocess
import sys
import time

import boto3
from botocore.exceptions import ClientError

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import routes as R  # noqa: E402

PROFILE = os.environ.get("AWS_PROFILE", "agent-toolkit")
REGION = os.environ.get("AWS_REGION", "ap-south-1")
ACCOUNT = os.environ.get("EXPECTED_ACCOUNT", "468704514492")
API_ID = os.environ.get("API_ID", "aksdwfbnn5")
ROLE_NAME = "rakshak-lambda-role"
BUCKET = "rakshak-models-vishalganesan"
LAYER_NAME = "rakshak-ml-layer"

BACKEND = os.path.join(ROOT, "backend")
DIST = os.path.join(BACKEND, "build", "dist")
LAYER_BUILD = os.path.join(BACKEND, "build", "layer")


def log(msg):
    print(msg, flush=True)


def session():
    return boto3.Session(profile_name=PROFILE, region_name=REGION)


def guard_account(sess):
    ident = sess.client("sts").get_caller_identity()
    if ident["Account"] != ACCOUNT:
        sys.exit(f"ABORT: account {ident['Account']} != expected {ACCOUNT}. "
                 f"Never deploy to the wrong account.")
    log(f"  identity ok — {ident['Arn']}")


# ─────────────────────────────────────────────────────────────────────────────
# Build
# ─────────────────────────────────────────────────────────────────────────────

def build_zips(dry_run):
    log("[build] pytest (must pass before anything ships)")
    if not dry_run:
        r = subprocess.run([sys.executable, "-m", "pytest", "tests", "-q"], cwd=ROOT)
        if r.returncode != 0:
            sys.exit("ABORT: tests failed — fix before deploying")
    log("[build] build_zips.sh")
    if not dry_run:
        subprocess.run(["bash", "backend/build/build_zips.sh"], cwd=ROOT, check=True)


def build_layer_if_needed(force, dry_run):
    """Rebuild + publish the ML layer only when requirements-layer.txt changed
    (tracked by a hash file next to the built zip) or --layer/force was passed."""
    req_path = os.path.join(ROOT, "requirements-layer.txt")
    with open(req_path) as fh:
        req_hash = hashlib.sha256(fh.read().encode()).hexdigest()[:16]
    marker = os.path.join(LAYER_BUILD, f".built-{req_hash}")
    if os.path.exists(marker) and not force:
        log(f"[layer] unchanged (requirements hash {req_hash}) — skip rebuild")
        return None

    log(f"[layer] requirements changed or --layer passed — rebuilding (hash {req_hash})")
    if dry_run:
        return None
    os.makedirs(LAYER_BUILD, exist_ok=True)
    site = os.path.join(LAYER_BUILD, "python", "lib", "python3.12", "site-packages")
    subprocess.run(["rm", "-rf", os.path.join(LAYER_BUILD, "python")], check=True)
    os.makedirs(site, exist_ok=True)
    subprocess.run([
        sys.executable, "-m", "pip", "install",
        "--platform", "manylinux2014_x86_64", "--platform", "manylinux_2_28_x86_64",
        "--python-version", "3.12", "--implementation", "cp", "--abi", "cp312",
        "--only-binary=:all:", "--no-deps", "--target", site,
        "-r", req_path,
    ], check=True)
    # conservative trim only — do NOT remove numpy.f2py or any importable
    # submodule; v8 of this layer broke numpy import by deleting numpy/f2py.
    subprocess.run(f"find '{site}' -type d -name __pycache__ -exec rm -rf {{}} + 2>/dev/null; "
                    f"find '{site}' -type d -iname tests -exec rm -rf {{}} + 2>/dev/null; "
                    f"find '{site}' -name '*.pyc' -delete", shell=True)

    zip_path = os.path.join(LAYER_BUILD, "rakshak-ml-layer.zip")
    if os.path.exists(zip_path):
        os.remove(zip_path)
    subprocess.run(["zip", "-qr9", zip_path, "python"], cwd=LAYER_BUILD, check=True)
    size_mb = os.path.getsize(zip_path) / 1e6
    log(f"[layer] built {zip_path} ({size_mb:.1f} MB zipped)")

    sess = session()
    s3 = sess.client("s3")
    key = f"layers/rakshak-ml-layer-{req_hash}.zip"
    s3.upload_file(zip_path, BUCKET, key)
    lam = sess.client("lambda")
    resp = lam.publish_layer_version(
        LayerName=LAYER_NAME,
        Description=f"numpy+scipy+xgboost-cpu, py3.12 x86_64 (requirements hash {req_hash})",
        Content={"S3Bucket": BUCKET, "S3Key": key},
        CompatibleRuntimes=["python3.12"],
        CompatibleArchitectures=["x86_64"],
    )
    arn = resp["LayerVersionArn"]
    log(f"[layer] published {arn}")
    open(marker, "w").close()
    return arn


# ─────────────────────────────────────────────────────────────────────────────
# Optional: create-from-empty primitives (only with --create-infra)
# ─────────────────────────────────────────────────────────────────────────────

TABLES = [
    {"TableName": "rakshak-sos-alerts", "KeySchema": [{"AttributeName": "sos_id", "KeyType": "HASH"}],
     "AttributeDefinitions": [{"AttributeName": "sos_id", "AttributeType": "S"}], "BillingMode": "PAY_PER_REQUEST"},
    {"TableName": "rakshak-patrols", "KeySchema": [{"AttributeName": "patrol_id", "KeyType": "HASH"}],
     "AttributeDefinitions": [{"AttributeName": "patrol_id", "AttributeType": "S"}], "BillingMode": "PAY_PER_REQUEST"},
    {"TableName": "rakshak-incidents",
     "KeySchema": [{"AttributeName": "incident_id", "KeyType": "HASH"}, {"AttributeName": "created_at", "KeyType": "RANGE"}],
     "AttributeDefinitions": [{"AttributeName": "incident_id", "AttributeType": "S"}, {"AttributeName": "created_at", "AttributeType": "S"}],
     "BillingMode": "PAY_PER_REQUEST"},
    {"TableName": "rakshak-zones", "KeySchema": [{"AttributeName": "pincode", "KeyType": "HASH"}],
     "AttributeDefinitions": [{"AttributeName": "pincode", "AttributeType": "S"}], "BillingMode": "PAY_PER_REQUEST"},
    {"TableName": "rakshak-users", "KeySchema": [{"AttributeName": "user_id", "KeyType": "HASH"}],
     "AttributeDefinitions": [{"AttributeName": "user_id", "AttributeType": "S"}], "BillingMode": "PAY_PER_REQUEST"},
]


def ensure_tables(sess, dry_run):
    ddb = sess.client("dynamodb")
    existing = set(ddb.list_tables().get("TableNames", []))
    for t in TABLES:
        if t["TableName"] in existing:
            log(f"[dynamodb] {t['TableName']} exists — skip")
            continue
        log(f"[dynamodb] creating {t['TableName']}")
        if not dry_run:
            ddb.create_table(**t)
            ddb.get_waiter("table_exists").wait(TableName=t["TableName"])


def ensure_gsi(sess, dry_run):
    ddb = sess.client("dynamodb")
    desc = ddb.describe_table(TableName="rakshak-sos-alerts")["Table"]
    have = {g["IndexName"] for g in desc.get("GlobalSecondaryIndexes", [])}
    if "status-created_at-index" in have:
        log("[dynamodb] status-created_at-index exists — skip")
        return
    log("[dynamodb] creating status-created_at-index on rakshak-sos-alerts")
    if dry_run:
        return
    ddb.update_table(
        TableName="rakshak-sos-alerts",
        AttributeDefinitions=[
            {"AttributeName": "status", "AttributeType": "S"},
            {"AttributeName": "created_at", "AttributeType": "S"},
        ],
        GlobalSecondaryIndexUpdates=[{"Create": {
            "IndexName": "status-created_at-index",
            "KeySchema": [{"AttributeName": "status", "KeyType": "HASH"},
                         {"AttributeName": "created_at", "KeyType": "RANGE"}],
            "Projection": {"ProjectionType": "ALL"},
        }}],
    )


def ensure_bucket(sess, dry_run):
    s3 = sess.client("s3")
    try:
        s3.head_bucket(Bucket=BUCKET)
        log(f"[s3] {BUCKET} exists — skip")
        return
    except ClientError:
        pass
    log(f"[s3] creating {BUCKET}")
    if dry_run:
        return
    if REGION == "us-east-1":
        s3.create_bucket(Bucket=BUCKET)
    else:
        s3.create_bucket(Bucket=BUCKET, CreateBucketConfiguration={"LocationConstraint": REGION})


LAMBDA_ROLE_TRUST = {
    "Version": "2012-10-17",
    "Statement": [{"Effect": "Allow", "Principal": {"Service": "lambda.amazonaws.com"},
                   "Action": "sts:AssumeRole"}],
}
LAMBDA_ROLE_DYNAMODB_POLICY = {
    "Version": "2012-10-17",
    "Statement": [{
        "Effect": "Allow",
        "Action": ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:DeleteItem",
                  "dynamodb:Query", "dynamodb:Scan", "dynamodb:BatchWriteItem", "dynamodb:BatchGetItem"],
        "Resource": [f"arn:aws:dynamodb:{REGION}:{ACCOUNT}:table/rakshak-*"],
    }],
}


def ensure_lambda_role(sess, dry_run):
    iam = sess.client("iam")
    try:
        iam.get_role(RoleName=ROLE_NAME)
        log(f"[iam] {ROLE_NAME} exists — skip")
        return f"arn:aws:iam::{ACCOUNT}:role/{ROLE_NAME}"
    except ClientError:
        pass
    log(f"[iam] creating {ROLE_NAME}")
    if dry_run:
        return f"arn:aws:iam::{ACCOUNT}:role/{ROLE_NAME}"
    iam.create_role(RoleName=ROLE_NAME, AssumeRolePolicyDocument=json.dumps(LAMBDA_ROLE_TRUST))
    iam.attach_role_policy(RoleName=ROLE_NAME,
                           PolicyArn="arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole")
    iam.attach_role_policy(RoleName=ROLE_NAME, PolicyArn="arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess")
    iam.put_role_policy(RoleName=ROLE_NAME, PolicyName="RakshakDynamoDBAccess",
                        PolicyDocument=json.dumps(LAMBDA_ROLE_DYNAMODB_POLICY))
    time.sleep(8)  # IAM propagation before the role is usable by Lambda
    return f"arn:aws:iam::{ACCOUNT}:role/{ROLE_NAME}"


def ensure_api(sess, dry_run):
    apigw = sess.client("apigatewayv2")
    try:
        api = apigw.get_api(ApiId=API_ID)
        log(f"[apigw] {API_ID} exists — skip ({api['ApiEndpoint']})")
        return API_ID
    except ClientError:
        pass
    log(f"[apigw] {API_ID} not found — creating a NEW HTTP API "
        f"(its id will differ from {API_ID}; update frontend API_BASE_URL after this run)")
    if dry_run:
        return API_ID
    resp = apigw.create_api(
        Name="rakshak-api", ProtocolType="HTTP",
        CorsConfiguration={"AllowOrigins": ["*"], "AllowMethods": ["GET", "POST", "PATCH", "OPTIONS"],
                          "AllowHeaders": ["content-type", "authorization", "x-amz-date", "x-api-key"],
                          "MaxAge": 300},
    )
    new_id = resp["ApiId"]
    apigw.create_stage(ApiId=new_id, StageName="$default", AutoDeploy=True)
    log(f"[apigw] created {new_id} — https://{new_id}.execute-api.{REGION}.amazonaws.com")
    return new_id


# ─────────────────────────────────────────────────────────────────────────────
# Function code + config
# ─────────────────────────────────────────────────────────────────────────────

def local_zip_sha256_b64(fn):
    with open(os.path.join(DIST, f"{fn}.zip"), "rb") as fh:
        return base64.b64encode(hashlib.sha256(fh.read()).digest()).decode()


def ensure_function(sess, fn, role_arn, layer_arn, dry_run):
    lam = sess.client("lambda")
    zip_path = os.path.join(DIST, f"{fn}.zip")
    local_sha = local_zip_sha256_b64(fn)

    try:
        cfg = lam.get_function_configuration(FunctionName=fn)
        exists = True
    except ClientError:
        exists = False
        cfg = None

    if not exists:
        log(f"[lambda] {fn} does not exist — creating")
        if dry_run:
            return
        with open(zip_path, "rb") as fh:
            lam.create_function(
                FunctionName=fn, Runtime="python3.12", Role=role_arn,
                Handler="lambda_function.lambda_handler",
                Code={"ZipFile": fh.read()},
                Timeout=30, MemorySize=(1024 if fn in R.ML_FUNCTIONS else 256),
                Environment={"Variables": {"AWS_REGION_OVERRIDE": REGION}},
                Layers=[layer_arn] if (fn in R.ML_FUNCTIONS and layer_arn) else [],
            )
        lam.get_waiter("function_active_v2").wait(FunctionName=fn)
        return

    if cfg["CodeSha256"] == local_sha:
        log(f"[lambda] {fn} code unchanged — skip update-function-code")
    else:
        log(f"[lambda] {fn} code changed — updating")
        if not dry_run:
            with open(zip_path, "rb") as fh:
                lam.update_function_code(FunctionName=fn, ZipFile=fh.read())
            lam.get_waiter("function_updated_v2").wait(FunctionName=fn)

    if fn in R.ML_FUNCTIONS and layer_arn:
        current_layers = [l["Arn"] for l in (cfg.get("Layers") or [])]
        if layer_arn not in current_layers:
            log(f"[lambda] {fn} attaching layer {layer_arn}")
            if not dry_run:
                lam.update_function_configuration(FunctionName=fn, Layers=[layer_arn])
                lam.get_waiter("function_updated_v2").wait(FunctionName=fn)
        else:
            log(f"[lambda] {fn} layer already current — skip")


# ─────────────────────────────────────────────────────────────────────────────
# API Gateway routes + permissions
# ─────────────────────────────────────────────────────────────────────────────

def _paginate(fn, key, **kwargs):
    """apigatewayv2 list calls page via NextToken; boto3 has no built-in
    paginator for this service, so page manually. Missing this caused
    deploy.py to see only the first ~25 routes and try to recreate the rest."""
    items = []
    token = None
    while True:
        resp = fn(NextToken=token, **kwargs) if token else fn(**kwargs)
        items.extend(resp.get(key, []))
        token = resp.get("NextToken")
        if not token:
            return items


def _integration_function_name(uri):
    """Extract the Lambda function name from an integration URI, which AWS
    stores in either form depending on how the integration was created:
      short:  arn:aws:lambda:<region>:<acct>:function:<name>
      long:   arn:aws:apigateway:<region>:lambda:path/2015-03-31/functions/
              arn:aws:lambda:<region>:<acct>:function:<name>/invocations
    """
    marker = ":function:"
    if marker not in uri:
        return None
    tail = uri.split(marker, 1)[1]
    return tail.split("/", 1)[0]


def ensure_routes(sess, api_id, dry_run):
    apigw = sess.client("apigatewayv2")
    lam = sess.client("lambda")

    integrations = _paginate(apigw.get_integrations, "Items", ApiId=api_id)
    fn_integration = {}
    for i in integrations:
        name = _integration_function_name(i.get("IntegrationUri", ""))
        if name and name not in fn_integration:
            fn_integration[name] = i["IntegrationId"]

    existing_routes = {r["RouteKey"]: r["RouteId"]
                       for r in _paginate(apigw.get_routes, "Items", ApiId=api_id)}
    log(f"[apigw] {len(existing_routes)} existing routes, {len(fn_integration)} existing integrations")

    permitted_fns = set()

    for method, path, fn in R.ALL_ROUTES:
        if fn not in fn_integration:
            fn_arn = f"arn:aws:lambda:{REGION}:{ACCOUNT}:function:{fn}"
            log(f"[apigw] creating integration for {fn}")
            if dry_run:
                fn_integration[fn] = "DRYRUN"
            else:
                resp = apigw.create_integration(
                    ApiId=api_id, IntegrationType="AWS_PROXY", IntegrationUri=fn_arn,
                    PayloadFormatVersion="2.0", IntegrationMethod="POST",
                )
                fn_integration[fn] = resp["IntegrationId"]

        route_key = f"{method} {path}"
        if route_key in existing_routes:
            pass  # route already targets whatever it targets — don't silently repoint it
        else:
            log(f"[apigw] creating route {route_key} -> {fn}")
            if not dry_run:
                resp = apigw.create_route(ApiId=api_id, RouteKey=route_key,
                                          Target=f"integrations/{fn_integration[fn]}")
                existing_routes[route_key] = resp["RouteId"]

        if fn not in permitted_fns:
            permitted_fns.add(fn)
            ensure_invoke_permission(lam, fn, api_id)


def ensure_invoke_permission(lam, fn, api_id):
    source_arn = f"arn:aws:execute-api:{REGION}:{ACCOUNT}:{api_id}/*/*"
    try:
        policy = json.loads(lam.get_policy(FunctionName=fn)["Policy"])
        for stmt in policy.get("Statement", []):
            cond = stmt.get("Condition", {}).get("ArnLike", {}).get("AWS:SourceArn", "")
            if cond == source_arn:
                return  # already permitted for this whole API
    except ClientError:
        pass
    try:
        lam.add_permission(
            FunctionName=fn, StatementId=f"apigw-invoke-{api_id}",
            Action="lambda:InvokeFunction", Principal="apigateway.amazonaws.com",
            SourceArn=source_arn,
        )
        log(f"[lambda] granted apigateway invoke on {fn}")
    except ClientError as e:
        if e.response["Error"]["Code"] != "ResourceConflictException":
            raise


# ─────────────────────────────────────────────────────────────────────────────
# CloudWatch
# ─────────────────────────────────────────────────────────────────────────────

def ensure_observability(sess, dry_run):
    logs = sess.client("logs")
    cw = sess.client("cloudwatch")
    for fn in R.MANAGED_FUNCTIONS:
        group = f"/aws/lambda/{fn}"
        try:
            desc = logs.describe_log_groups(logGroupNamePrefix=group)["logGroups"]
            current = next((g for g in desc if g["logGroupName"] == group), None)
            if current and current.get("retentionInDays") == 14:
                pass
            else:
                log(f"[logs] setting 14d retention on {group}")
                if not dry_run:
                    logs.put_retention_policy(logGroupName=group, retentionInDays=14)
        except ClientError:
            pass  # log group doesn't exist yet — created on first invoke

        alarm = f"rakshak-{fn[len('rakshak-'):]}-errors"
        existing = cw.describe_alarms(AlarmNames=[alarm]).get("MetricAlarms", [])
        if existing:
            continue
        log(f"[cloudwatch] creating alarm {alarm}")
        if not dry_run:
            cw.put_metric_alarm(
                AlarmName=alarm, AlarmDescription=f"Errors on {fn} in a 5-minute window",
                Namespace="AWS/Lambda", MetricName="Errors",
                Dimensions=[{"Name": "FunctionName", "Value": fn}],
                Statistic="Sum", Period=300, EvaluationPeriods=1, Threshold=1,
                ComparisonOperator="GreaterThanOrEqualToThreshold", TreatMissingData="notBreaching",
            )


# ─────────────────────────────────────────────────────────────────────────────
# main
# ─────────────────────────────────────────────────────────────────────────────

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--layer", action="store_true", help="force ML layer rebuild even if unchanged")
    ap.add_argument("--create-infra", action="store_true",
                    help="also create IAM role / tables / GSI / S3 bucket / API if missing")
    ap.add_argument("--dry-run", action="store_true", help="print planned changes, mutate nothing")
    args = ap.parse_args()

    log(f"Rakshak-SIH deploy — profile={PROFILE} region={REGION} account={ACCOUNT} api={API_ID}"
        f"{' [DRY RUN]' if args.dry_run else ''}")

    sess = session()
    guard_account(sess)

    build_zips(args.dry_run)

    role_arn = f"arn:aws:iam::{ACCOUNT}:role/{ROLE_NAME}"
    api_id = API_ID
    if args.create_infra:
        ensure_bucket(sess, args.dry_run)
        role_arn = ensure_lambda_role(sess, args.dry_run)
        ensure_tables(sess, args.dry_run)
        ensure_gsi(sess, args.dry_run)
        api_id = ensure_api(sess, args.dry_run)

    layer_arn = build_layer_if_needed(args.layer, args.dry_run)
    if layer_arn is None and not args.dry_run:
        # unchanged — resolve the current $LATEST version to (re)attach if a
        # function is missing it (e.g. a brand-new function on --create-infra)
        lam = sess.client("lambda")
        try:
            v = lam.list_layer_versions(LayerName=LAYER_NAME, MaxItems=1)["LayerVersions"]
            layer_arn = v[0]["LayerVersionArn"] if v else None
        except ClientError:
            layer_arn = None

    for fn in R.MANAGED_FUNCTIONS:
        ensure_function(sess, fn, role_arn, layer_arn, args.dry_run)

    ensure_routes(sess, api_id, args.dry_run)
    ensure_observability(sess, args.dry_run)

    log("\ndeploy.py done.")
    if not args.dry_run:
        log(f"Verify with:  bash deploy/verify.sh https://{api_id}.execute-api.{REGION}.amazonaws.com")


if __name__ == "__main__":
    main()
