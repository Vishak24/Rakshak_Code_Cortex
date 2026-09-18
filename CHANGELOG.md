# Changelog

## 1.0.0 — Production migration to Code_Cortex

Consolidated the project from the `RAKSHAK ALL` archive (multiple parallel
generations, duplicated assets, mixed planning docs) into this single
production repository, and closed the remaining gaps against the target
architecture.

### Backend

- Migrated `Rakshak-SIH`'s backend (Lambda source, shared module, tests,
  deploy tooling) into the clean `backend/`, `deploy/`, `tests/` layout,
  fixing every path assumption the move touched — verified byte-identical
  build output and a zero-mutation `deploy.py --dry-run` before any other
  change.
- Merged `rakshak-sos-feed` into `rakshak-sos-handler` (no functional
  change — same shared module, no cross-Lambda dependency) and retired
  `rakshak-score-refresh` (its one caller no longer exists in the current
  dashboard). Live routes repointed and verified green before retirement.
- Added `rakshak-night-monitor` and `rakshak-routing` to managed build/deploy
  (previously deployed but unmanaged).
- Added a warm-up guard (`{"warm": true}` early return) to the 4
  contract-serving Lambdas and a 5-minute EventBridge keep-warm rule.
- Fixed `scripts/seed_demo_state.py`'s `clear_active()` to release patrols
  via `release_patrol()`/`settle_patrol_to_patrolling()` instead of a
  hand-rolled update that referenced attribute names (`target_lat`,
  `target_lng`) the current handlers never actually write.
- Bumped `BUILD_VERSION` to `1.0.0`.

### Frontends

- Migrated `citizen-app`, `police-app` (Flutter) and `dashboard`
  (React/Vite), removing build artifacts, duplicated AI-planning docs, and
  one unreferenced duplicate asset per app — verified `flutter analyze`
  (0 errors, both apps) and `npm run build` (dashboard) after the move.

### ML / documentation

- Added `docs/DATASET_CARD.md`, `docs/FEATURE_ENGINEERING.md`,
  `docs/ML_PIPELINE.md` documenting the dataset's actual synthetic
  provenance honestly, and `docs/CODE_CORTEX_AI_ML.md` for judge-facing
  model-choice questions.
- Added the full documentation suite: `AWS_ARCHITECTURE.md`,
  `DEPLOYMENT.md`, `API_REFERENCE.md`, `OBSERVABILITY.md`,
  `SECURITY_MODEL.md`, `DATABASE_SCHEMA.md`, `PATROL_SIMULATION.md`,
  `DEMO_RUNBOOK.md`, `USP_AND_INNOVATION.md`.

### Infrastructure

- No new AWS account resources created from empty — the existing live
  account (`468704514492`, `ap-south-1`) was adopted and updated
  idempotently throughout, per `deploy/deploy.py`'s check-first-then-create
  design.

---

For the state of the backend *before* this migration (the AWS greenfield
recovery/fix pass against the live account), see
`docs/ARCHITECTURE_AUDIT.md` and the git history of the source archive.
