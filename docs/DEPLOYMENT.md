# Deployment

`deploy/deploy.py` is the single deploy tool. It is **idempotent by design**:
every resource is check-first-then-create, every code push is skipped when
the built zip's SHA256 already matches what's live, and running it twice in
a row with no source changes produces zero mutating AWS calls on the second
run.

## Prerequisites

```bash
aws sso login --profile agent-toolkit     # or: aws login --profile agent-toolkit
aws sts get-caller-identity --profile agent-toolkit --region ap-south-1
#   must show Account: 468704514492
```

`deploy.py` calls `guard_account()` before anything else and **aborts
immediately** if the caller's account doesn't match — it will never deploy
to the wrong account, even by accident.

## Commands

```bash
make test          # 30 pytest cases, no AWS — must pass before anything ships
make build          # test + backend/build/build_zips.sh -> backend/build/dist/*.zip
make deploy-dry     # full plan, zero mutations — run this first, always
make deploy          # ship code + layer (if requirements-layer.txt changed) + missing routes
make deploy-infra   # deploy + create-from-empty primitives (tables/bucket/role) if genuinely absent
make verify          # live smoke test: health, all frozen-contract reads, 44-zone heatmap,
                     #   full SOS lifecycle (create -> accept -> status -> resolve), performance
```

Equivalent direct invocations:

```bash
python3 deploy/deploy.py --dry-run
python3 deploy/deploy.py
python3 deploy/deploy.py --create-infra
python3 deploy/deploy.py --layer            # force a layer rebuild even if requirements unchanged
```

## What "idempotent" means here, concretely

| Resource | Check | Action if present | Action if absent |
|---|---|---|---|
| DynamoDB table | `list_tables` | skip | `create_table` + wait |
| `status-created_at-index` GSI | `describe_table` | skip | `update_table` with `GlobalSecondaryIndexUpdates` |
| S3 bucket | `head_bucket` | skip | `create_bucket` |
| IAM role | `get_role` | skip | `create_role` + attach policies |
| Lambda function | `get_function` | `update_function_code` **only if** the local zip's SHA256 differs from the deployed `CodeSha256` | `create_function` |
| Lambda layer | hash of `requirements-layer.txt` vs. a marker file at `backend/build/layer/.built-<hash>` | skip rebuild | rebuild, publish new version, attach to `ML_FUNCTIONS` |
| API Gateway route | `get_routes` (paginated) | skip — **never silently repoints an existing route** | `create_route` + `create_integration` if needed |
| CloudWatch alarm | `describe_alarms` | skip | `put_metric_alarm` |

The one deliberate exception to "never repoints an existing route": when a
function is *merged into* or *retired in favor of* another (see below),
repointing is a one-time, explicit, reviewed migration — not something
`ensure_routes` does automatically on every run.

## Reproducible builds

`backend/build/build_zips.sh` pins every staged file's mtime
(`touch -t 202601010000`) and zips with `TZ=UTC zip -qrX` before packaging.
Two builds of byte-identical source produce byte-identical zips — confirmed
this pass with `shasum -a 256` across a rebuild. This is what makes the
CodeSha256 comparison in `ensure_function` meaningful: without it, every
`make deploy` would re-publish every function even with no real code change.

## Layer rebuild policy

The ML layer (`rakshak-ml-layer`: numpy 2.1.3, scipy 1.14.1, xgboost-cpu
3.2.0, py3.12 x86_64) only rebuilds when `requirements-layer.txt`'s SHA256
changes, tracked by an empty marker file
`backend/build/layer/.built-<hash16>`. Current hash: `563878c2b272e161`
(layer version 9). **Do not delete `numpy/f2py`** or any other importable
submodule when trimming a rebuilt layer — layer version 8 did exactly that
and broke `import numpy` entirely on live invocation (caught via
`aws logs tail`, fixed by rebuilding v9 with conservative trimming only:
`__pycache__`, `tests` dirs, `*.pyc`). Kept in the version history as a
warning; never reuse v8.

## Retiring `sos-feed` / `score-refresh` (one-off, already applied)

`rakshak-sos-feed` was merged into `rakshak-sos-handler` and
`rakshak-score-refresh` was retired (no live caller) in the pass that
produced this repository. This was **not** a `deploy.py` capability — route
repointing and resource deletion are one-time structural changes, done as a
reviewed script, not folded into the idempotent tool:

1. Deploy the merged `rakshak-sos-handler` code (`make deploy` — ordinary path).
2. Repoint the 6 affected routes from the old integration to the new one
   with `apigatewayv2.update_route` (`Target=integrations/<sos-handler-id>`).
3. `make verify` — confirm green before touching anything destructive.
4. Delete the now-orphaned routes, integration, and function.

Step 4 requires an explicit approval this migration pass didn't have (AWS
resource deletion is treated as a destructive, shared-resource action) — see
`AWS_RESOURCES.md` for the current status of that cleanup.

## Rollback

Every managed Lambda keeps its full version history via `publish_layer_version`
/ `update_function_code`'s implicit versioning. To roll back a function:

```bash
aws lambda list-versions-by-function --function-name rakshak-sos-handler --profile agent-toolkit
aws lambda update-function-code --function-name rakshak-sos-handler \
  --s3-bucket rakshak-models-vishalganesan --s3-key <previous-version-zip-key> --profile agent-toolkit
```

No table is ever deleted by `deploy.py`, no API ID changes, and existing
route contracts are never silently repointed — so a bad deploy's blast
radius is limited to the specific function(s) whose code changed.
