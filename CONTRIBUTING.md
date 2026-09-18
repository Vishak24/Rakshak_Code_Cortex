# Contributing

## Project layout

See the repository layout section in [`README.md`](README.md). Backend
Lambda source lives in `backend/lambdas/`, one directory per function, with
shared logic vendored from `backend/lambdas/_shared/rakshak_common.py`.

## Backend changes

```bash
python3 -m pip install -r requirements-dev.txt
make test              # 30 pytest cases, no AWS needed — must pass before any deploy
```

- Every handler routes through `lambda_handler(event, context)` — add new
  routes there and in `deploy/routes.py` (`CONTRACT` for new frozen-contract
  paths, `LEGACY` for compatibility aliases).
- Shared logic (DynamoDB helpers, patrol simulation, ML resolver) belongs in
  `backend/lambdas/_shared/rakshak_common.py`, not duplicated per-handler —
  it's vendored into every function's zip by `backend/build/build_zips.sh`.
- Add a test in `tests/test_backend.py` for new behavior; `tests/conftest.py`
  provides an in-memory DynamoDB double so tests run with no AWS credentials.

## Deploying a change

```bash
make deploy-dry     # always run this first — see the exact plan, zero mutations
make deploy
make verify           # live smoke test
```

See [`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md) for the full idempotency
contract — `deploy.py` never repoints an existing route or recreates an
existing resource; understand that before adding new deploy-time behavior.

## Frontend changes

```bash
cd citizen-app && flutter pub get && flutter analyze lib
cd police-app  && flutter pub get && flutter analyze lib
cd dashboard   && npm ci && npm run build
```

Each Flutter app bundles its own copy of `assets/chennai_zones.geojson`,
`assets/chennai-pincodes.kml`, `assets/Final_Chennai_Pincode.kml` (declared
in `pubspec.yaml`) — don't remove these as "duplicates" of the backend's
`assets/chennai_zones.geojson`; each app needs its own bundled copy to
build.

## Documentation

`docs/` covers architecture, API, ML, security, and demo material — see the
index in `README.md`. Keep claims checkable: cite the code path or the live
API response a claim is based on, rather than describing intended behavior
that isn't actually implemented yet.

## Commit style

Small, scoped commits with a message describing *why*, not just *what* —
the diff already shows what changed.
