# GitHub Release Checklist

## Done

- [x] Clean repository structure at `Code_Cortex` root (`backend/`,
      `dashboard/`, `citizen-app/`, `police-app/`, `ml/`, `assets/`,
      `deploy/`, `tests/`, `docs/`, `scripts/` + required root files).
- [x] No duplicated folders, archived generations, or AI-planning docs
      copied from the source archive.
- [x] All hardcoded paths fixed for the new layout; verified with a
      zero-mutation `deploy.py --dry-run` and a byte-identical rebuild.
- [x] `rakshak-sos-feed` merged into `rakshak-sos-handler`;
      `rakshak-score-refresh` retired — both verified green live before
      and after.
- [x] `rakshak-night-monitor`, `rakshak-routing` added to managed
      build/deploy (previously deployed but unmanaged).
- [x] Warm-up guard + EventBridge keep-warm rule added to the 4
      contract-serving Lambdas.
- [x] 30/30 backend tests passing; live smoke test all-green
      (`tests/REPORT.md`).
- [x] Both Flutter apps analyze with 0 errors; dashboard builds.
- [x] Full documentation suite written (see `README.md`'s doc index).
- [x] Dataset documented honestly as synthetic, with real provenance and
      stated limitations — no fabricated dataset citation
      (`docs/DATASET_CARD.md`).
- [x] `.gitignore` covers build artifacts, `node_modules`, `.dart_tool`,
      env files, zips — without excluding tracked source
      (`backend/build/build_zips.sh` itself is not excluded).
- [x] `LICENSE` (MIT) at repo root.
- [x] Git repository initialized locally with a meaningful commit history.

## Not done — explicit, with why

- [ ] **Delete the orphaned `rakshak-sos-feed` / `rakshak-score-refresh`
      AWS resources.** Blocked by a permission gate on destructive
      shared-resource actions during this pass. They are fully orphaned
      (no route references them) and serve no traffic, so this is safe
      to defer, but should be done before calling the AWS side
      "fully clean." See `docs/AWS_RESOURCES.md` / `docs/DEPLOYMENT.md`
      for the exact commands.
- [ ] **SNS alerting on the CloudWatch error alarms.** Alarms exist and
      are `OK`; nothing pages anyone yet (`docs/OBSERVABILITY.md`).
- [ ] **API authentication.** Every route is currently public — the
      single largest gap before any real (non-demo) deployment
      (`docs/SECURITY_MODEL.md`).
- [ ] **Screenshots.** `README.md` and `docs/screenshots/` have
      placeholders — capture and add before publishing.
- [ ] **Team credits.** `README.md`'s "Team" section is a placeholder.

## Before `git push`

```bash
git remote add origin <your-repo-url>
git branch -M main          # already the default branch name from git init
git push -u origin main
```

Double-check before pushing:

```bash
git log --oneline                       # review the commit history
git show --stat HEAD                    # confirm the most recent commit's contents
grep -r "AKIA\|SECRET\|password" --include='*.py' --include='*.dart' --include='*.js' . || echo "clean"
```

No `.env`, no credentials, and no AWS access keys are tracked — verified
during this pass (embedded IAM keys were removed from `rakshak-reports-handler`
in the prior work this repository is built on; nothing in this migration
reintroduced any).
