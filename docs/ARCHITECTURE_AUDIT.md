# Claude-Architecture  
  
─────────────────────────────────────────────────────────────────────────────────────── 1 new message ────────────────────────────────────────────────────────────────────────────────────────  
  
Rakshak Architecture Audit  
  
1. Executive Summary  
  
Audited 2026-09-18 against ~/Documents/RAKSHAK-ALL (hyphenated on disk) and the live API https://aksdwfbnn5.execute-api.ap-south-1.amazonaws.com; the agent-toolkit AWS session is expired and default is a different account (777906435182), so every AWS statement is tagged [LIVE] (verified over HTTPS today), [DOC] (Sep-4 deployment docs, unverified) or [UNVERIFIED] (needs aws login).  
  
1. Base for implementation: Rakshak-SIH/. It is the only generation that is deployed, has a shared module (lambdas/_shared/rakshak_common.py), has tests (20/20 pass offline), and matches the three frontends. rakshak_aws_final/, rakshak-backend/, Rakshak/ are archives.  
2. ML inference is DOWN [LIVE]. All 44 zones, POST /predict and POST /score/refresh return source: "baseline", confidence 0.55. The SageMaker endpoint (rakshak-risk-endpoint, ml.m5.large real-time) is no longer serving; the S3 fallback tier is broken (layer has no xgboost; MODEL_KEY defaults to the old RandomForest pickle). The Sep-4 docs claiming "44/44 sagemaker" are stale.  
3. The failed fallback chain costs ~3 s per warm call [LIVE] on /dashboard/snapshot (2.97 s) and /heatmap/live (3.03 s): 44 × (SageMaker fail + S3 attempt). Non-ML routes are 0.18–0.23 s warm; cold starts 3–5 s.  
4. Frozen contract: 12 of 14 paths return 404 [LIVE]. 2 exist at the exact path (/dashboard/snapshot, /dashboard/timeline); 7 are path aliases of working handlers with identical payloads; 5 are genuinely new (GET /incident/{id}, GET /incident/{id}/eta, PATCH /incident/{id}/accept, GET /health, GET /version).  
5. One live Lambda has no source in the repository. POST /citizens/ping, GET /police/citizens/active, GET /police/route all return 200 [LIVE] and are called by the police app, but no handler in Rakshak-SIH/lambdas/, the old deploy scripts, or the 579 KB session logs serves them. Must be recovered from AWS before any cleanup.  
6. No IaC. Infra was created by boto3 scripts embedding Lambda source as string literals and by a markdown file of CLI commands. No SAM/CDK/Makefile/Dockerfile/pinned requirements.  
7. Realtime is polling only (2–10 s) in all three apps. No WebSocket/AppSync/SSE exists. Keep polling.  
8. Decisions: Lambda-local XGBoost from S3 becomes the primary inference tier (verified feasible: numpy+scipy+xgboost-cpu ≈ 150 MB < 250 MB); SageMaker becomes optional/env-gated (Serverless Inference if kept; do not recreate the ml.m5.large endpoint). Merge rakshak-sos-feed into rakshak-sos-handler (one incident service). Add contract routes as aliases on the existing API, keep legacy routes live so frontends migrate via config edits only. Replace DEPLOY_COMMANDS.md with an idempotent deploy.py. Add one GSI. Everything else is patch-in-place.  
  
2. Repository Audit  
  
Marks: KEEP / PATCH / DELETE (later, after recovery steps) / IGNORE (non-code or generated). Build caches, node_modules, venv, .dart_tool, build/ are omitted (all IGNORE).  
  
RAKSHAK-ALL/  
├── CODEBASE_OVERVIEW.md                 PATCH   Aug-12; predates Rakshak-SIH, names rakshak_aws_final as "main" — mark superseded  
├── Context_Files/                       IGNORE  AIdeas-competition planning notes (3 md files), non-code  
├── Demo+Pics/                           IGNORE  screenshots  
├── Rakshak/Rakshak/                     DELETE  untouched create-expo-app template (own .git, no Rakshak code)  
├── Rakshak_ML/                          KEEP    training pipeline + v2 dataset; venv/ IGNORE  
│   ├── train_chennai_risk_model.py      KEEP    XGBClassifier(200,6,0.1), 17 features, writes pkl+json+encoders  
│   ├── Finaldataset.py, generate_*.py   KEEP    dataset builders (v2 = Finaldataset.py)  
│   ├── chennai_sos_enhanced_data_v2.csv KEEP    latest dataset (also in S3)  
│   ├── rakshak_chennai_model.{pkl,json} KEEP    v1 (Feb-18) — historical; v2 lives only in S3  
│   ├── retrain_rf.py testmodel.py sample.py urgent.py  DELETE  ad-hoc scratch  
│   └── test_risk_model.*                DELETE  scratch model  
├── rakshak-backend/                     DELETE  Feb-era single hardcoded inference Lambda + 180 MB vendored  
│                                                site-packages + 3 zipped layers; superseded (no xgboost either)  
├── rakshak_aws_final/                   ARCHIVE — the Gemma-era generation  
│   ├── .git/                            KEEP    only real git history (origin Vishak24/rakshak); re-home it  
│   ├── deploy/                          KEEP-AS-ARCHIVE → DELETE once deploy.py exists (only record of  
│   │                                            table/role/API creation: task1_dynamodb, task3_apigw_v2)  
│   ├── lib/ android/ ios/ web/ test/    DELETE  superseded by Rakshak-SIH/{citizen-app,police-app}  
│   ├── rakshak-dashboard/               DELETE  superseded by Rakshak-SIH/dashboard (keeps GemmaPanel,  
│   │                                            usePatrolSimulation.js — the sim already ported to Python)  
│   ├── gemma_api.py GEMMA4.md           IGNORE  Gemma/Ollama layer, out of SIH scope  
│   ├── prototypes/ landing/             IGNORE  static mockups / marketing page  
│   ├── CLAUDE.md (579 KB)               DELETE  AI session log; byte-identical copy ×3  
│   ├── AUDIT_REPORT.md SUBMISSION_CONTEXT.md SECURITY.md CONTRIBUTING.md  IGNORE  May-era docs  
│   └── tests/ playwright-report/ .github/  DELETE  Playwright snapshots of the old UI  
└── Rakshak-SIH/                         ★ PRODUCTION ROOT (no .git yet — git init here)  
    ├── lambdas/_shared/rakshak_common.py     KEEP+PATCH  985 lines: http, ddb, geo, zones, patrol sim, ML  
    ├── lambdas/_shared/chennai_zones.geojson KEEP        64 polygons keyed by Pincode  
    ├── lambdas/rakshak-sos-handler/          KEEP+PATCH  absorbs sos-feed; contract aliases  
    ├── lambdas/rakshak-sos-feed/             MERGE       → sos-handler (duplicated lifecycle code)  
    ├── lambdas/rakshak-patrol-handler/       KEEP+PATCH  status whitelist; /dashboard/patrols alias  
    ├── lambdas/rakshak-dashboard/            KEEP+PATCH  /dashboard/heatmap alias, /health, /version  
    ├── lambdas/rakshak-test-inference/       KEEP+PATCH  owns /prediction/{zone} + /predict  
    ├── lambdas/rakshak-score-refresh/        DELETE      route retired; only ref is unadopted shared/ template  
    ├── lambdas/rakshak-reports-handler/      KEEP        extension; dashboard Reports panel uses it  
    ├── assets/patrol_routes.json             KEEP        make canonical; drop PATROL_UNITS literal  
    ├── assets/chennai_zones.geojson          KEEP        identical to _shared copy — keep one  
    ├── build/build_zips.sh                   PATCH       bundle assets + package layout; build/dist IGNORE  
    ├── deploy/DEPLOY_COMMANDS.md             PATCH       becomes runbook; commands move to deploy.py  
    ├── deploy/sagemaker/                     KEEP        build_model.py, code/inference.py, deploy.sh, validation.json  
    ├── seed/seed_demo_state.py               KEEP+PATCH  release uses legacy attribute names  
    ├── tests/{conftest.py,test_backend.py}   KEEP        in-memory DynamoDB double; 20 tests pass  
    ├── launch_demo.sh                        KEEP+PATCH  add /health; already pre-warms  
    ├── frontend-integration/                 PATCH       API_ENDPOINTS.md/types.ts → frozen contract; sample-data KEEP  
    ├── frontend-architecture/shared/         IGNORE      unadopted TS/react-query template (drop scoreRefresh)  
    ├── citizen-app/ police-app/              KEEP        Flutter web apps (lib/ differs in 10 files; 90% duplicate)  
    │   ├── deploy/                           DELETE      byte-identical copy of rakshak_aws_final/deploy  
    │   ├── CLAUDE.md GEMMA4.md gemma_api.py fix-geojson.js  DELETE  copies of the old generation  
    │   └── .env (GOOGLE_API_KEY placeholder) IGNORE      not bundled, gitignored  
    ├── dashboard/                            KEEP        React+Vite; rakshak_audit.cjs, scripts/ DELETE (one-off)  
    ├── README.md                             PATCH       "Nothing here has touched AWS yet" is false  
    ├── DEMO_READY.md DEMO_READINESS_AUDIT.md PATCH       SageMaker claims stale as of today  
    └── .demo-logs/ .pytest_cache/ build/dist IGNORE      generated (already gitignored)  
  
Production code: Rakshak-SIH/lambdas/*, assets/*, seed/, tests/, build/, deploy/sagemaker/, the three apps.  
Obsolete: rakshak-backend/, Rakshak/, rakshak_aws_final/{lib,rakshak-dashboard,deploy(v1 scripts + hotfixes),tests}, Rakshak-SIH/lambdas/rakshak-score-refresh, */deploy/ copies, all CLAUDE.md.  
  
Duplicated files:  
- CLAUDE.md ×3 byte-identical (rakshak_aws_final, citizen-app, police-app) — 1.7 MB of session log.  
- deploy/ ×3 byte-identical (rakshak_aws_final, citizen-app, police-app).  
- chennai_zones.geojson ×4 identical (SIH/assets, SIH/_shared, citizen-app/assets, rakshak_aws_final/assets).  
- Flutter lib/: citizen-app vs police-app differ in 10 files (sos_*, risk_score*, intelligence/sentinel screens, main.dart); vs rakshak_aws_final 17 files.  
- Dashboard: Rakshak-SIH/dashboard/src vs rakshak_aws_final/rakshak-dashboard/src diverged (new: IncidentTimeline, SafetyScore, useActiveIncidents, useSnapshot; old: GemmaPanel, UsersNotHomeCard, usePatrolSimulation, data/patrolRoutes.js).  
- Patrol routes: assets/patrol_routes.json = rakshak_common.PATROL_UNITS = old patrolRoutes.js (three sources).  
- Zone registry: rakshak_common.ZONE_COORDS/ZONE_NAMES vs Dart pincode_map.dart, sentinel_controller.dart, sos_alert.dart vs dashboard/src/constants/zones.js — values and names differ (600001 = Parrys vs Park Town).  
- Model artifacts: Rakshak_ML/rakshak_chennai_model.pkl (Mar-13, 1.1 MB) ≠ rakshak-backend/model/rakshak_chennai_model.pkl (Feb-23, 666 KB) ≠ S3 v2; three zipped layers in rakshak-backend.  
- Deploy scripts v1 (task2_lambdas.py, task3_apigw.py) vs v2.  
- LIVE_STATES tuple defined in 3 Lambdas; _LEVELS map in score-refresh duplicates safety_to_level.  
  
Outdated documentation: Rakshak-SIH/README.md (says nothing touched AWS), DEMO_READY.md + deploy/sagemaker/DEPLOYMENT_REPORT.md (SageMaker InService — false today), DEMO_READINESS_AUDIT.md (account unreachable — contradicted), CODEBASE_OVERVIEW.md (pre-SIH), frontend-integration/API_ENDPOINTS.md (old paths; will not match frozen contract), Context_Files/* (AIdeas era), all rakshak_aws_final/*.md, frontend-architecture/*.md (proposes react-query rewrite never adopted).  
  
Unused scripts: rakshak_aws_final/deploy/{task2_lambdas,task3_apigw,task4_seed,fix_real_data,fix_score_refresh_lambda,sos_cancelled_lambda}.py (v1 + one-off hotfixes whose code is superseded), rakshak-backend/layer/lambda_code/lambda_function.py, Rakshak_ML/{retrain_rf,testmodel,sample,urgent}.py, */fix-geojson.js, */gemma_api.py, dashboard/rakshak_audit.cjs, dashboard/scripts/*, .github/workflows/playwright.yml ×3.  
  
Reusable assets: chennai_zones.geojson, patrol_routes.json, Final_Chennai_Pincode.kml, ZONE_* registries + _ZONE_FEATURE_STATS + AREA_ENCODING (encoder-exact), frontend-integration/sample-data/*.json (19 fixtures), types.ts, tests/conftest.py (DynamoDB double), seed_demo_state.py, launch_demo.sh, deploy/sagemaker/*, Rakshak_ML training scripts + v2 CSV.  
  
3. AWS Infrastructure Audit  
  
Region ap-south-1, account 468704514492 [DOC].  
  
┌────────────────┬────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┬──────────────────────────────┬──────────────────┐  
│    Service     │                                                      Resource                                                      │            State             │       Tag        │  
├────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼──────────────────────────────┼──────────────────┤  
│                │ HTTP API aksdwfbnn5, stage $default, auto-deploy; preflight response carries access-control-max-age: 300 and       │ ~24 routes inferred from     │ LIVE (probes) /  │  
│ API Gateway    │ normalised header values the Lambda CORS dict does not set → native CORS configuration appears applied (confirm    │ scripts + probes (see §5)    │ DOC (route list) │  
│                │ with get-api); the OPTIONS /{proxy+} → Lambda route is then redundant                                              │                              │                  │  
├────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼──────────────────────────────┼──────────────────┤  
│                │ rakshak-sos-handler, rakshak-sos-feed, rakshak-patrol-handler, rakshak-reports-handler, rakshak-test-inference,    │                              │ LIVE (behaviour) │  
│ Lambda         │ rakshak-score-refresh, rakshak-dashboard — Python 3.12, lambda_function.lambda_handler; sos/patrol/reports 256     │ Responding                   │  / DOC (config)  │  
│                │ MB/30 s; test-inference & dashboard 1024 MB/30 s; score-refresh 512 MB                                             │                              │                  │  
├────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼──────────────────────────────┼──────────────────┤  
│ Lambda         │ unnamed function serving /citizens/ping, /police/citizens/active, /police/route                                    │ Responding; source not in    │ LIVE             │  
│                │                                                                                                                    │ repo                         │                  │  
├────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼──────────────────────────────┼──────────────────┤  
│ Lambda         │ rakshak-scan-inference (legacy S3-pkl inference; its role has s3:GetObject)                                        │ Exists per DEPLOY_COMMANDS;  │ DOC              │  
│                │                                                                                                                    │ no known route               │                  │  
├────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼──────────────────────────────┼──────────────────┤  
│ Lambda layers  │ rakshak-deps:5 (contents unknown), rakshak-ml-layer:7 (numpy, scipy, sklearn, joblib — no xgboost, ~180 MB)        │ Attached to ML functions     │ DOC              │  
├────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼──────────────────────────────┼──────────────────┤  
│ Lambda         │ Architecture (x86_64 vs arm64), env vars (whether RAKSHAK_AWS_ACCESS_KEY_ID/SECRET is still on sos-handler)        │ Unknown                      │ UNVERIFIED       │  
├────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼──────────────────────────────┼──────────────────┤  
│                │ rakshak-sos-alerts (PK sos_id), rakshak-patrols (PK patrol_id), rakshak-incidents (PK incident_id, SK created_at — │ 20 patrols, 0 active         │ LIVE (data) /    │  
│ DynamoDB       │  citizen reports), rakshak-zones (PK pincode, unused), rakshak-users (referenced, unused), + 3 undocumented ("8    │ incidents, 44 timeline       │ DOC (names)      │  
│                │ tables" per DEMO_READY)                                                                                            │ events, reports rows         │                  │  
├────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼──────────────────────────────┼──────────────────┤  
│ DynamoDB       │ GSIs                                                                                                               │ None — every list is a full  │ DOC              │  
│                │                                                                                                                    │ scan                         │                  │  
├────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼──────────────────────────────┼──────────────────┤  
│                │ rakshak-lambda-role (v2-script functions; has sagemaker:InvokeEndpoint per DOC), rakshak-sagemaker-role;           │ Which role each function     │                  │  
│ IAM            │ rakshak-dashboard was created preferring rakshak-scan-inference's role (has s3:GetObject) per DEPLOY_COMMANDS; IAM │ runs under, and their        │ UNVERIFIED       │  
│                │  user key AKIA…7YPR formerly embedded in Lambda env (still a valid credential per DOC)                             │ policies, unknown            │                  │  
├────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼──────────────────────────────┼──────────────────┤  
│                │ rakshak-models-vishalganesan: rakshak_chennai_model_v2.pkl, label_encoder_{area,neighborhood}_v2.pkl,              │                              │                  │  
│ S3             │ data/chennai_sos_enhanced_data_v2.csv, sagemaker/model-v2-20260904.tar.gz (model.pkl + xgb_model.json +            │ Exists                       │ DOC              │  
│                │ booster.json + code/inference.py); older rakshak_chennai_model.pkl (RandomForest Apr-06), sagemaker/model.tar.gz   │                              │                  │  
│                │ (RF)                                                                                                               │                              │                  │  
├────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼──────────────────────────────┼──────────────────┤  
│ SageMaker      │ model rakshak-risk-model-v2, endpoint-config rakshak-risk-endpoint-config-v2, endpoint rakshak-risk-endpoint (1×   │ Not serving — every route    │ LIVE             │  
│                │ ml.m5.large real-time)                                                                                             │ falls to baseline            │                  │  
├────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼──────────────────────────────┼──────────────────┤  
│ CloudWatch     │ default Lambda log groups; no retention policy, no alarms, no dashboard                                            │ —                            │ DOC (absence)    │  
├────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼──────────────────────────────┼──────────────────┤  
│ EventBridge    │ none                                                                                                               │ —                            │ DOC (absence)    │  
├────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼──────────────────────────────┼──────────────────┤  
│ WebSocket API  │ none                                                                                                               │ —                            │ LIVE (repo +     │  
│ / AppSync      │                                                                                                                    │                              │ probes)          │  
└────────────────┴────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┴──────────────────────────────┴──────────────────┘  
  
Missing: 12 of the 14 contract routes (7 aliases + 5 new); /health, /version; a GSI on rakshak-sos-alerts; xgboost in the ML layer; booster.json as a standalone S3 object (exists only inside the tar); log retention; 5xx alarms; warmer rule; any IaC/idempotent deploy; a record of which Lambda serves the citizens routes.  
  
Broken references: rakshak_common.MODEL_KEY default rakshak_chennai_model.pkl → the RandomForest artifact, not v2 (S3 tier would serve the wrong model even with a working layer); SAGEMAKER_ENDPOINT=rakshak-risk-endpoint → endpoint absent; rakshak-ml-layer:7 lacks xgboost (documented follow-up never done); deploy/DEPLOY_COMMANDS.md step 4 stacks rakshak-deps:5 + ml-layer:7 on test-inference (size unmeasured); T_USERS/rakshak-zones referenced-but-unused; citizen app calls POST /gemma/checkin and /gemma/escalate on the AWS base → 404 (silently falls back to a canned message).  
  
Must NOT be recreated: API aksdwfbnn5 (default base URL compiled into all three apps), the existing tables (live seeded data, names hardcoded), rakshak-lambda-role, the S3 bucket, existing Lambda function names/ARNs (permissions + integrations reference them), layers (publish new versions only), the ml.m5.large real-time endpoint (≈$95/month idle; its teardown is exactly today's outage).  
  
4. Lambda Audit  
  
Lambda: rakshak-sos-handler  
Purpose: SOS create + auto-dispatch, citizen feed, dispatch, resolve, cancel  
Trigger: API GW proxy v2  
Routes today: POST/GET /sos/live, POST /sos/dispatch/{id}, PATCH /sos/resolve/{id}, POST /sos/cancelled  
Dependencies: rakshak_common; DDB sos-alerts, patrols  
Status: Working [LIVE]; validation present  
Decision: KEEP + PATCH — becomes the single incident service; add contract routes  
────────────────────────────────────────  
Lambda: rakshak-sos-feed  
Purpose: Police feed + status transitions  
Trigger: API GW  
Routes today: GET /police/sos/active, PATCH /police/sos/{sos_id}/status  
Dependencies: same  
Status: Working [LIVE]; dispatch/resolve logic duplicated with sos-handler  
Decision: MERGE → sos-handler (same table, same transitions); repoint legacy routes, then delete  
────────────────────────────────────────  
Lambda: rakshak-patrol-handler  
Purpose: Compute-on-read patrol positions, optimize, manual status  
Trigger: API GW  
Routes today: GET /patrols, POST /patrol/optimize, PATCH /patrols/{id}/status  
Dependencies: common; DDB patrols  
Status: Working [LIVE] 0.23 s  
Decision: KEEP + PATCH — status whitelist; serve GET /dashboard/patrols  
────────────────────────────────────────  
Lambda: rakshak-dashboard  
Purpose: Snapshot, timeline, heatmap, zone prediction  
Trigger: API GW  
Routes today: GET /dashboard/snapshot, /dashboard/timeline, /heatmap/live, /prediction/zone/{zoneId}  
Dependencies: common; ML layer; DDB read  
Status: Working but degraded (3 s, baseline) [LIVE]  
Decision: KEEP + PATCH — aliases, /health, /version, batch+cache scoring; hand /prediction to test-inference  
────────────────────────────────────────  
Lambda: rakshak-test-inference  
Purpose: Safety score POST /predict  
Trigger: API GW  
Routes today: POST /predict  
Dependencies: common; rakshak-deps:5 + ml-layer:7  
Status: Working, baseline only [LIVE]  
Decision: KEEP + PATCH — owns GET /prediction/{zone}; drop rakshak-deps if unused  
────────────────────────────────────────  
Lambda: rakshak-score-refresh  
Purpose: Legacy batch scores  
Trigger: API GW  
Routes today: POST /score/refresh  
Dependencies: common; ML layer  
Status: Working [LIVE]; no caller (retired in api.dart, dashboard uses /heatmap/live; only frontend-architecture/shared template references it)  
Decision: REMOVE route + function  
────────────────────────────────────────  
Lambda: rakshak-reports-handler  
Purpose: Citizen report moderation  
Trigger: API GW  
Routes today: POST /reports/submit, GET /reports, PATCH /reports/{approve,reject}/{id}  
Dependencies: common; DDB rakshak-incidents  
Status: Working [LIVE] 200  
Decision: KEEP (extension; dashboard Reports.jsx)  
────────────────────────────────────────  
Lambda: unknown name  
Purpose: Citizen location pings, night-watch counts, route helper  
Trigger: API GW  
Routes today: POST /citizens/ping, GET /police/citizens/active, GET /police/route  
Dependencies: unknown table(s)  
Status: Working [LIVE]; source missing  
Decision: RECOVER (get-integrations → get-function → download zip → commit as functions/citizen/), then KEEP  
────────────────────────────────────────  
Lambda: rakshak-scan-inference  
Purpose: Old S3-pickle inference  
Trigger: none known  
Routes today: none  
Dependencies: old layer  
Status: Legacy  
Decision: REMOVE the function only after recording its role and policies — rakshak-dashboard may run under that role  
  
5. API Contract Audit  
  
Frozen contract (14 paths) vs live API: 2 exist, 7 alias, 5 missing [LIVE].  
  
┌──────────────────────────┬───────────────────────────────┬──────────────────────────────┬─────────────────┬─────────────────────────────────────────────────────────────────────────┐  
│         Contract         │        Exists today as        │            Status            │  Owner after    │                                  Note                                   │  
│                          │                               │                              │      patch      │                                                                         │  
├──────────────────────────┼───────────────────────────────┼──────────────────────────────┼─────────────────┼─────────────────────────────────────────────────────────────────────────┤  
│ POST /sos                │ POST /sos/live                │ Needs Patch (alias)          │ sos-handler     │ same body (user_id, latitude/longitude, pincode…) and 201 response      │  
├──────────────────────────┼───────────────────────────────┼──────────────────────────────┼─────────────────┼─────────────────────────────────────────────────────────────────────────┤  
│ GET /incident/{id}       │ — (GET /sos/live?user_id=     │ Missing                      │ sos-handler     │ get_item(sos_id) + _enrich (patrol position, live ETA, events)          │  
│                          │ scans)                        │                              │                 │                                                                         │  
├──────────────────────────┼───────────────────────────────┼──────────────────────────────┼─────────────────┼─────────────────────────────────────────────────────────────────────────┤  
│ GET /incident/{id}/eta   │ — (ETA embedded in feeds)     │ Missing                      │ sos-handler     │ {sos_id, status, assigned_patrol_id, eta_seconds, distance_m,           │  
│                          │                               │                              │                 │ patrol_position} from compute_patrol_view                               │  
├──────────────────────────┼───────────────────────────────┼──────────────────────────────┼─────────────────┼─────────────────────────────────────────────────────────────────────────┤  
│ GET /incidents/active    │ GET /police/sos/active        │ Needs Patch (alias)          │ sos-handler     │ keep ?patrol_id=, ?officer_lat/lng=; add ?user_id=                      │  
├──────────────────────────┼───────────────────────────────┼──────────────────────────────┼─────────────────┼─────────────────────────────────────────────────────────────────────────┤  
│ PATCH                    │ — (dispatch is automatic)     │ Missing                      │ sos-handler     │ assumption: additive acknowledgment — accepted_at, officer_id, event    │  
│ /incident/{id}/accept    │                               │                              │                 │ Accepted; status stays dispatched; auto-dispatch unchanged              │  
├──────────────────────────┼───────────────────────────────┼──────────────────────────────┼─────────────────┼─────────────────────────────────────────────────────────────────────────┤  
│ PATCH                    │ PATCH                         │ Needs Patch (alias)          │ sos-handler     │ whitelist + terminal guard already exist                                │  
│ /incident/{id}/status    │ /police/sos/{sos_id}/status   │                              │                 │                                                                         │  
├──────────────────────────┼───────────────────────────────┼──────────────────────────────┼─────────────────┼─────────────────────────────────────────────────────────────────────────┤  
│ PATCH                    │ PATCH /sos/resolve/{id}       │ Needs Patch (alias)          │ sos-handler     │ = status: resolved                                                      │  
│ /incident/{id}/resolve   │                               │                              │                 │                                                                         │  
├──────────────────────────┼───────────────────────────────┼──────────────────────────────┼─────────────────┼─────────────────────────────────────────────────────────────────────────┤  
│ GET /dashboard/snapshot  │ same                          │ Already Exists — Broken perf │ dashboard       │ fixed by §7                                                             │  
│                          │                               │  (3 s)                       │                 │                                                                         │  
├──────────────────────────┼───────────────────────────────┼──────────────────────────────┼─────────────────┼─────────────────────────────────────────────────────────────────────────┤  
│ GET /dashboard/patrols   │ GET /patrols                  │ Needs Patch (alias)          │ patrol-handler  │ identical array                                                         │  
├──────────────────────────┼───────────────────────────────┼──────────────────────────────┼─────────────────┼─────────────────────────────────────────────────────────────────────────┤  
│ GET /dashboard/timeline  │ same                          │ Already Exists               │ dashboard       │ 0.18 s                                                                  │  
├──────────────────────────┼───────────────────────────────┼──────────────────────────────┼─────────────────┼─────────────────────────────────────────────────────────────────────────┤  
│ GET /dashboard/heatmap   │ GET /heatmap/live             │ Needs Patch (alias) — Broken │ dashboard       │                                                                         │  
│                          │                               │  perf/source                 │                 │                                                                         │  
├──────────────────────────┼───────────────────────────────┼──────────────────────────────┼─────────────────┼─────────────────────────────────────────────────────────────────────────┤  
│ GET /prediction/{zone}   │ GET /prediction/zone/{zoneId} │ Needs Patch (alias) — Broken │ test-inference  │ keep 404 for unknown pincode                                            │  
│                          │                               │  source (baseline)           │                 │                                                                         │  
├──────────────────────────┼───────────────────────────────┼──────────────────────────────┼─────────────────┼─────────────────────────────────────────────────────────────────────────┤  
│ GET /health              │ —                             │ Missing                      │ dashboard       │ DDB reachability, ML tier + source, version                             │  
├──────────────────────────┼───────────────────────────────┼──────────────────────────────┼─────────────────┼─────────────────────────────────────────────────────────────────────────┤  
│ GET /version             │ —                             │ Missing                      │ dashboard       │ git sha + build time from env                                           │  
└──────────────────────────┴───────────────────────────────┴──────────────────────────────┴─────────────────┴─────────────────────────────────────────────────────────────────────────┘  
  
Extension routes — KEEP, outside the frozen contract, consumed by frontends: POST /predict (citizen, 4 call sites), GET /sos/live?user_id= (citizen own-incident poll), POST /sos/cancelled (citizen), POST /sos/dispatch/{id}, PATCH /patrols/{id}/status, POST /patrol/optimize, /reports/* ×4, POST /citizens/ping, GET /police/citizens/active, GET /police/route. Legacy paths stay live as aliases to the same Lambdas for one release so the three apps migrate by editing config/api.dart (×2) and src/config/api.js only.  
Retire: POST /score/refresh. Dead client calls: citizen /gemma/checkin, /gemma/escalate (404 today).  
  
6. Data Model Audit  
  
Logical entity: incidents = sos alerts = timeline  
Table: rakshak-sos-alerts  
Keys: PK sos_id (S)  
Indexes: none  
Notes: status ∈ active/dispatched/reached/resolved/cancelled; created_at/triggered_at/updated_at/dispatched_at/reached_at/resolved_at/cancelled_at (ISO-Z); user_id, username, pincode,  
zone_name, risk_level, battery, network; coords stored twice (lat/lng and latitude/longitude, legacy rows have NULL in one pair); assigned_patrol_id, assigned_officer,  assigned_vehicle,  
eta_seconds, officer_id, notes, user_phone; events[] = {type, ts, detail, patrol_id?, pincode?} — the timeline lives here, no separate table  
────────────────────────────────────────  
Logical entity: patrols  
Table: rakshak-patrols  
Keys: PK patrol_id (S)  
Indexes: none  
Notes: name, officer, vehicle, status (Patrolling/Responding/AtScene/Returning), zone, zone_name, cycle_start_ts (N epoch), assigned_sos_id, sos_lat/sos_lng, divert_start_ts,  
divert_from_lat/lng, return_start_ts, return_from_lat/lng, route? (JSON), updated_at. Position is never stored — derived on read  
────────────────────────────────────────  
Logical entity: citizen reports (misnamed)  
Table: rakshak-incidents  
Keys: PK incident_id (S), SK created_at (S)  
Indexes: none  
Notes: status pending/approved/rejected, approved_at/rejected_at, free-form body. Moderation must scan to find the SK  
────────────────────────────────────────  
Logical entity: analytics  
Table: —  
Keys: —  
Indexes: —  
Notes: computed on read (snapshot); rakshak-zones (PK pincode) exists but unused  
────────────────────────────────────────  
Logical entity: users  
Table: rakshak-users  
Keys: PK user_id (assumed)  
Indexes: —  
Notes: referenced by T_USERS, never accessed  
────────────────────────────────────────  
Logical entity: citizen pings  
Table: undocumented (1 of 3 unknown tables)  
Keys: ?  
Indexes: ?  
Notes: written by the missing Lambda  
  
Relationships: incident.assigned_patrol_id → patrol (1 patrol : ≤1 live incident, enforced by ConditionExpression); patrol.assigned_sos_id → incident (back-pointer); incident.pincode → zone registry (code constant, not a table); timeline event.patrol_id → patrol.  
  
Missing attributes: accepted_at, accepted_by (for /accept); schema_version; ttl on ping/test rows; incident source (citizen-web/police-web); patrol updated_at is the seed timestamp (never refreshed by compute-on-read — any UI binding shows a frozen time).  
  
Only schema change recommended: add GSI status-created_at-index (PK status, SK created_at) to rakshak-sos-alerts via UpdateTable — active feed, resolved_today, and timeline become Queries instead of scans. Optional second GSI user_id-created_at-index. No table is recreated or renamed; rakshak-incidents keeps its confusing name (document it).  
  
7. ML Pipeline Audit  
  
┌────────────────────┬─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┬────────────────────┐  
│        Item        │                                                                    Found                                                                    │       State        │  
├────────────────────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼────────────────────┤  
│ Model (canonical)  │ s3://rakshak-models-vishalganesan/rakshak_chennai_model_v2.pkl — XGBClassifier, multi:softprob, 3 classes, 300 trees, xgboost 3.2, trained  │ S3 only [DOC]; not │  
│                    │ 2026-04-17 on 20,800 synthetic rows                                                                                                         │  in repo           │  
├────────────────────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼────────────────────┤  
│ Cross-version      │ sagemaker/model-v2-20260904.tar.gz → xgb_model.json, booster.json (parity vs sklearn predict_proba asserted < 1e-4 in build_model.py)       │ S3 only, inside    │  
│ artifacts          │                                                                                                                                             │ tar                │  
├────────────────────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼────────────────────┤  
│ Local artifacts    │ Rakshak_ML/rakshak_chennai_model.{pkl,json} v1 (Feb-18, 200 trees, acc 1.0 / CV 0.99975); rakshak-backend/model/*.pkl (different bytes)     │ historical         │  
├────────────────────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼────────────────────┤  
│ Encoders           │ label_encoder_area_v2.pkl (49 classes), label_encoder_neighborhood_v2.pkl (6) in S3; replicated exactly as AREA_ENCODING /                  │ consistent [DOC]   │  
│                    │ NEIGHBORHOOD_ENCODING literals + _ZONE_AREA, _ZONE_NEIGHBORHOOD pincode maps in rakshak_common                                              │                    │  
├────────────────────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼────────────────────┤  
│ Feature schema     │ 17 features, order fixed: FEATURE_ORDER == validation.json == inference.py (rejects ≠17 cols); features_for_zone() fills time features +    │ consistent         │  
│                    │ per-pincode means (_ZONE_FEATURE_STATS); no scaler                                                                                          │                    │  
├────────────────────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼────────────────────┤  
│ Inference code     │ rakshak_common.predict_safety() 3-tier; _risk_to_safety() (45/85 weights → safety 15–100, floor 10); safety_to_level() bands 60/34;         │ working logic,     │  
│                    │ deploy/sagemaker/code/inference.py (multi-row instances)                                                                                    │ broken tiers       │  
├────────────────────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼────────────────────┤  
│ SageMaker endpoint │ deploy/sagemaker/{build_model.py,deploy.sh,code/inference.py} — reproducible, immutable model names, update-endpoint in place               │ reusable; endpoint │  
│  code              │                                                                                                                                             │  absent            │  
├────────────────────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼────────────────────┤  
│ Local fallback     │ _load_s3_model() → joblib.load pickle; layer 7 has no xgboost → fails; MODEL_KEY defaults to old RF pickle; failure not cached → 44         │ broken             │  
│                    │ downloads per heatmap                                                                                                                       │                    │  
├────────────────────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼────────────────────┤  
│ Baseline           │ ZONE_RISK_BASELINE + night/evening bump, conf 0.55                                                                                          │ serving everything │  
│                    │                                                                                                                                             │  today             │  
└────────────────────┴─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┴────────────────────┘  
  
Can Lambda load the model directly from S3? Yes — verified feasible:  
- xgboost-cpu==3.2.0 (manylinux_2_28_x86_64, py3): 5.6 MB wheel / 18 MB unpacked; hard deps only numpy, scipy (checked from wheel METADATA).  
- Layer = numpy (~30 MB) + scipy (~90 MB) + xgboost-cpu (18 MB) ≈ 140 MB unzipped, under the 250 MB combined function+layers limit. Must replace rakshak-ml-layer:7 (180 MB, includes sklearn) — not stack; drop rakshak-deps:5 from test-inference unless proven needed.  
- Load booster.json (3 MB) with xgb.Booster().load_model() — no sklearn, no pickle version skew; identical probabilities to the SageMaker container (same artifact).  
- Lambda python3.12 runtime is AL2023 (glibc 2.34 ≥ manylinux_2_28). Function architecture must be confirmed x86_64 (UNVERIFIED); build the layer for whatever Architectures reports.  
- Cold start est. 1.5–2.5 s (imports + one S3 GET, cached in /tmp and module global); warm batch inference for 44 rows < 10 ms.  
  
Final ML inference architecture (no retraining, no model replacement):  
  
GET /prediction/{zone}   GET /dashboard/heatmap   POST /predict   (+ /dashboard/snapshot top-5)  
            │                      │                   │  
            └──────────────────────┴───────────────────┘  
                                   ▼  
        rakshak_common.ml.predict_batch(pincodes, when, overrides) → [SafetyScore]  
            builds N × 17 rows via features_for_zone(); one call for all rows  
                                   ▼  
  tier 1  LOCAL  (default, ML_PRIMARY=local)  
          layer rakshak-ml-layer:v8 = numpy + scipy + xgboost-cpu 3.2.0  
          s3://rakshak-models-vishalganesan/models/v2/booster.json   (one-time upload from the tar)  
          Booster cached per container; predict → probs[N][3]           source="s3-model"  
            │ any failure → circuit open 300 s (module-level), fall through  
                                   ▼  
  tier 2  SAGEMAKER  (optional; skipped when SAGEMAKER_ENDPOINT is empty)  
          single invoke {"instances": [N rows]} → predictions + probabilities   source="sagemaker"  
          if kept: Serverless Inference config (no idle cost), never the ml.m5.large endpoint  
            │ failure → circuit open 300 s  
                                   ▼  
  tier 3  BASELINE  ZONE_RISK_BASELINE + time-of-day, conf 0.55                source="baseline"  
                                   ▼  
        _risk_to_safety(probs) → safety 10–100 ; level = safety_to_level(safety) ; confidence = max(probs)  
  
S3 stays the single source of truth for artifacts; deploy/sagemaker/deploy.sh remains the way to (re)create the optional tier; validation.json becomes a unit-test fixture (8 rows, expected probabilities) executed against the local tier in CI.  
  
8. Patrol Simulation Audit  
  
┌────────────────────┬───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┬──────────────────────────────────────┐  
│     Component      │                                                           Where                                                           │               Verdict                │  
├────────────────────┼───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼──────────────────────────────────────┤  
│ patrol_routes.json │ assets/ — 20 units P001–P020, closed loops [lat,lng], home pincode; also hardcoded as PATROL_UNITS in rakshak_common      │ dual source → JSON canonical         │  
├────────────────────┼───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼──────────────────────────────────────┤  
│ Movement engine    │ position_on_route() distance = 40 km/h × elapsed since cycle_start_ts, modulo loop length; lerp_toward() straight-line at │ reusable; straight-line, not         │  
│                    │  55 km/h for divert, 40 km/h return                                                                                       │ road-following (acceptable for demo) │  
├────────────────────┼───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼──────────────────────────────────────┤  
│ ETA engine         │ remaining_m / speed while Responding; 0 at scene; null otherwise; surfaced as eta_seconds + distance_m in patrol views    │ reusable                             │  
│                    │ and incident enrichments                                                                                                  │                                      │  
├────────────────────┼───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼──────────────────────────────────────┤  
│                    │ assign_nearest_patrol() ranks free units by haversine from their computed position, conditional write (status=Patrolling  │ reusable; verified live (20 units    │  
│ Rerouting          │ AND attribute_not_exists(assigned_sos_id)), next-nearest on contention; release_patrol() → Returning to waypoint 0;       │ moving, 0.23 s) and by tests         │  
│                    │ settle_patrol_to_patrolling() lazily on GET /patrols                                                                      │ (contention, settle)                 │  
├────────────────────┼───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼──────────────────────────────────────┤  
│ Availability       │ Patrolling ∧ no assigned_sos_id; Awaiting Patrol event when all busy; one patrol per incident                             │ reusable                             │  
└────────────────────┴───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┴──────────────────────────────────────┘  
  
Reusable as-is: yes. Patches, with reasons:  
1. PATCH /patrols/{id}/status writes any string ("banana" accepted) → whitelist the four states and clear divert/return attributes when forcing Patrolling.  
2. seed_demo_state.clear_active() releases units with REMOVE assigned_sos_id, target_lat, target_lng — legacy names; real attributes are sos_lat/sos_lng/divert_* and cycle_start_ts is not reset → stale attributes and a position jump. Use release_patrol()/settle_patrol_to_patrolling().  
3. Routes loaded from the bundled JSON at import (like the GeoJSON) and PATROL_UNITS literal deleted — one source.  
4. Settle-on-read only runs in GET /patrols; also run it inside snapshot/active-feed reads so counts never show a finished Returning unit (cheap: same conditional update).  
5. updated_at on the wire is the seed timestamp; emit generated_at per response instead.  
6. Responding units park at ETA 0 until an officer marks reached — intended (human confirmation); keep, document.  
  
9. Dashboard Aggregation Audit  
  
Today (rakshak-dashboard): snapshot = scan patrols + scan sos + 44 sequential predict_safety calls (→ 3 s); timeline = scan sos → flatten events[] (synthesised for legacy rows) → sort desc → limit ≤ 500; heatmap = same 44 predictions − 6/incident-today − 10/active, floor 10; prediction = single zone; patrols = patrol-handler. The Sep-4 finding that snapshot was unconsumed is resolved — the SIH dashboard has useSnapshot.js (5 s).  
  
Clean aggregation flow:  
  
GET /dashboard/patrols  (3 s poll)   patrol-handler: scan(rakshak-patrols) → compute_patrol_view ×20 (settle Returning)  
GET /dashboard/heatmap  (10 s poll)  dashboard:  
                                      scores  = ml.predict_batch(44 pincodes)           ← one call, cached per (pincode, hour)  
                                      density = counts per pincode from sos GSI (active | created today)  
                                      zone    = clamp(score − 6·today − 10·active, 10, 100); level = safety_to_level  
GET /dashboard/snapshot (5 s poll)   dashboard:  
                                      patrols  → counts by status  
                                      active   = Query GSI status ∈ {active,dispatched,reached}  
                                      today    = Query GSI status ∈ {resolved,cancelled} ∧ created_at ≥ IST day start  
                                      top-5    = heatmap zones sorted by safety_score (reuses the cached scores)  
GET /dashboard/timeline (5 s poll)   dashboard: Query GSI (recent first) → flatten events[] → sort ts desc → limit  
GET /prediction/{zone}  (on demand)  test-inference: predict_batch([zone]) with oGET /health                          dashboard: describe_table(patrols) + cached ML tier probe + version  
  
Until the GSI exists, scan_all remains (fine at demo scale: < 1,000 rows); the 3 s problem is the ML chain, fixed in §7.  
  
10. Realtime Recommendation  
  
Keep HTTP short-polling on the existing HTTP API. Rationale: all three apps already poll (useActiveIncidents 2 s, useLivePatrols 3 s, useSnapshot 5 s, useTimeline 5 s, useRiskData 10 s; police map_screen 2 s; citizen own-incident 2 s); measured propagation citizen→dashboard ≤ 1.1 s [DOC] with 0.2 s route latency [LIVE]; three clients × ~1.5 req/s is negligible Lambda/DynamoDB cost; zero frontend changes beyond config.  
  
Make polling robust: Cache-Control: no-store + generated_at on every response; keep client 8 s timeouts; keep hot containers warm between demos with one EventBridge rule (every 5 min, {"warm": true} payload → immediate return) on sos-handler, patrol-handler, dashboard, test-inference; optional provisioned concurrency = 1 on those four for demo day only; launch_demo.sh already pre-warms.  
  
Rejected: WebSocket API (separate API type, $connect/$disconnect handlers, connections table, fan-out from every write path, rewrite of 5 dashboard hooks and 2 Flutter pollers); AppSync (GraphQL schema + resolvers + new client SDKs in Flutter and React); SSE (HTTP API cannot stream; Lambda response streaming only via Function URLs → second base URL and CORS surface).  
  
11. Deployment Plan  
  
Found: no template.yaml, samconfig.toml, Makefile, Dockerfile; requirements.txt only in rakshak-backend (unpinned); build/build_zips.sh (vendors rakshak_common.py + geojson into 7 zips); deploy/DEPLOY_COMMANDS.md (manual CLI, account guard, rollback notes); deploy/sagemaker/deploy.sh; rakshak_aws_final/deploy/task*.py (boto3, source embedded as strings, IAM keys pushed into Lambda env); launch_demo.sh; netlify.toml (dashboard); .github/workflows/playwright.yml (old UI).  
  
Local  
1. Python 3.12 venv; pip install -r requirements-dev.txt (boto3, pytest — pinned).  
2. make test → pytest tests with the in-memory DynamoDB double + validation.json parity test for the local ML tier (xgboost-cpu installed in the venv).  
3. make build → build/dist/*.zip (handler + rakshak_common/ package + assets/) and build/layer/rakshak-ml-layer.zip — binary-only wheels for python3.12 and the confirmed function architecture (pip platform download or the SAM build image), size asserted < 250 MB unzipped.  
4. Frontends: launch_demo.sh against the live API (no local backend); optional make local-api (stdlib http.server router → handlers, fake DDB) for offline frontend work.  
  
AWS (aws login --profile agent-toolkit, guard on account 468704514492)  
make deploy → deploy/deploy.py, idempotent: build → publish layer version if requirements-layer.txt hash changed → per function create-or-update code and configuration (runtime, memory, timeout, layers, env, role) → ensure API Gateway integrations + routes (contract + legacy aliases) → invoke permissions → CloudWatch log retention 14 d → smoke verify (/health 200, /dashboard/patrols = 20, /prediction/600017 source=s3-model, POST/PATCH round-trip with a __verify__ user then purge). Prints previous function versions for rollback. SageMaker (optional tier): deploy/sagemaker/deploy.sh with a Serverless Inference config.  
  
Demo  
T-30 aws login; make deploy (no-op when unchanged); python3 seed/seed_demo_state.py --apply --clear-active; make warm; bash launch_demo.sh (adds /health check). T-5 open dashboard → citizen → police. Post-demo seed_demo_state.py --only-clear --apply. Frontends hosted: Netlify (dashboard/netlify.toml base fixed) or local Vite preview + flutter build web --target lib/main_citizen.dart / lib/main.dart.  
  
12. Technical Debt / Cleanup List  
  
Report only — nothing fixed.  
  
Dead code / duplication  
- rakshak-sos-feed duplicates dispatch and resolve logic present in sos-handler (_dispatch ≈ _set_status(dispatched), _resolve ≈ _set_status(resolved)); LIVE_STATES defined three times; _LEVELS in score-refresh shadows safety_to_level.  
- rakshak_common.py (985 lines) mixes HTTP, DynamoDB coercion, geo, zone registry (250 lines of literals), patrol sim, ML.  
- PATROL_UNITS literal duplicates assets/patrol_routes.json; chennai_zones.geojson ×4; zone registries in 5 places with differing values.  
- rakshak-backend/layer/python (180 MB vendored site-packages incl. numpy tests) and three layer zips committed.  
- CLAUDE.md ×3 (1.7 MB), deploy/ ×3, Rakshak/Rakshak Expo template, v1 deploy scripts, hotfix scripts, Gemma layer files inside SIH apps.  
- frontend-architecture/shared (react-query layer) never adopted; references retired /score/refresh.  
- Citizen app still calls /gemma/checkin and /gemma/escalate (404).  
  
Inconsistent constants  
- zone_name('600001') = Parrys in Python vs Park Town in Dart; 600034 and 600006 both "Nungambakkam"; ZONE_COORDS differs from Finaldataset.py coordinates for the same pincodes.  
- Incident status lowercase (dispatched) vs patrol status PascalCase (Responding); rakshak-incidents table holds reports.  
- MODEL_KEY default points to the RF pickle; SAGEMAKER_ENDPOINT default assumes an endpoint that no longer exists.  
- Baseline bands (SAFETY_LOW=60/34) live in one place but _baseline_prediction recomputes risk differently from _risk_to_safety.  
  
Missing validation  
- /reports/submit stores any JSON body verbatim; PATCH /patrols/{id}/status accepts any status; _set_status ignores unknown patrol_id bodies; POST /sos accepts arbitrary extra keys and persists them (item[k] = v); ?limit on timeline parsed but other query params unchecked; POST /predict with lat/lng outside Chennai snaps to the nearest zone silently.  
- parse_body() swallows malformed JSON as {} — only /sos distinguishes empty from malformed.  
  
Error handling gaps  
- except Exception: pass around release_patrol, settle_patrol_to_patrolling, patrol AtScene update, and dispatch inside _set_status — a failed release leaves a patrol stuck in Responding with no log line.  
- server_error(e) returns raw exception text to clients; test-inference converts every failure into a 200 baseline, hiding real faults.  
- assign_nearest_patrol string-matches "ConditionalCheckFailed" on the exception instead of catching ClientError with the code.  
  
Logging / observability  
- Only two print statements (ML tier failures); no request id, route, latency, or structured JSON; no log retention; no alarms; no X-Ray; no Powertools. Cold starts and the 3 s chain were invisible until probed.  
  
Environment variables  
- AWS_REGION_OVERRIDE (the runtime already sets AWS_REGION); table names overridable but never varied; ML config split across SAGEMAKER_ENDPOINT/MODEL_BUCKET/MODEL_KEY with wrong defaults; VITE_SIMULATION_MODE dead; .env (GOOGLE_API_KEY placeholder) in three app dirs.  
  
Security  
- No authentication or authorization on any route (anyone can resolve any incident, cancel any SOS, moderate reports); CORS * with Authorization allowed; OPTIONS /{proxy+} Lambda route is redundant if native CORS is confirmed (two places define CORS).  
- IAM user access keys were pushed into Lambda environment variables by the v1/v2 deploy scripts; removed from reports-handler and score-refresh per docs, unconfirmed on sos-handler; the key (AKIA…7YPR) is still a valid credential per docs → rotate/delete. No literal secrets found in repo files.  
- seed_demo_state.py hardcodes the profile and performs deletes; launch_demo.sh kills whatever holds ports 3000–3002.  
- One or two roles serve every function (no least privilege); which function runs under which role, and whether s3:GetObject is granted, is unverified.  
  
Performance  
- scan_all on every list/aggregate; N+1 get_item per incident for patrol enrichment; 44 sequential model calls per heatmap/snapshot with no batching or caching; tier failures not memoised.  
  
Data hygiene  
- Legacy rows with latitude: NULL next to lat strings; events[] absent on old rows (synthesised on read); patrol updated_at frozen; test rows identified by user_id heuristics.  
  
Audit footprint: this audit issued read-only GETs plus one POST /citizens/ping with user_id="__audit_probe__" (200) — a single ping row in the undocumented pings table; no incidents were created.  
  
13. Final Production Architecture  
  
Repository root = today's Rakshak-SIH/ (git-initialised, history from rakshak_aws_final/.git re-homed if wanted). AWS function names are unchanged; directory names are the logical names.  
  
rakshak/  
├── Makefile                          test | build | layer | deploy | warm | seed | verify | demo  
├── requirements-dev.txt              boto3, pytest, xgboost-cpu, numpy, scipy (pinned)  
├── backend/  
│   ├── shared/rakshak_common/        vendored into every zip by build (Python package, not one file)  
│   │   ├── __init__.py               re-exports for the existing `import rakshak_common as rc` call sites  
│   │   ├── http.py                   resp/ok/created/errors, event parsing, CORS, structured log()  
│   │   ├── ddb.py                    to_ddb/from_ddb/num/coord, table(), scan_all, query_gsi, append_events  
│   │   ├── geo.py                    haversine, point_in_ring, zone_for_point (loads assets/chennai_zones.geojson)  
│   │   ├── zones.py                  ZONE_COORDS/NAMES/BASELINE, encoders, _ZONE_FEATURE_STATS, is_known_zone  
│   │   ├── patrols.py                PATROL_UNITS (from assets/patrol_routes.json), route geometry,  
│   │   │                             compute_patrol_view, assign_nearest_patrol, release, settle  
│   │   ├── incidents.py              transition(sos_id, to, actor, notes) — the ONE lifecycle state machine  
│   │   │                             (create/dispatch/accept/reached/resolve/cancel + events + patrol side-effects)  
│   │   └── ml.py                     features_for_zone, predict_batch (local → sagemaker → baseline,  
│   │                                 circuit breaker, /tmp cache), _risk_to_safety, safety_to_level  
│   ├── functions/  
│   │   ├── incident/handler.py       Lambda rakshak-sos-handler   (absorbs rakshak-sos-feed)  
│   │   ├── patrol/handler.py         Lambda rakshak-patrol-handler  
│   │   ├── prediction/handler.py     Lambda rakshak-test-inference (ML layer)  
│   │   ├── dashboard/handler.py      Lambda rakshak-dashboard      (ML layer; + health/version)  
│   │   ├── reports/handler.py        Lambda rakshak-reports-handler  
│   │   └── citizen/handler.py        recovered Lambda (pings / citizens-active / route)  
│   ├── assets/                       chennai_zones.geojson, patrol_routes.json, version.json (written by build)  
│   ├── layer/                        requirements-layer.txt (numpy, scipy, xgboost-cpu==3.2.0), build_layer.sh  
│   ├── tests/                        conftest.py (DDB double), test_incidents.py, test_patrols.py,  
│   │                                 test_ml.py (validation.json parity), test_routes.py (every contract path)  
│   ├── seed/seed_demo_state.py  
│   └── deploy/  
│       ├── deploy.py                 idempotent: layer → functions → routes → permissions → retention → verify  
│       ├── routes.py                 single table: route-key → function (contract + legacy aliases)  
│       ├── verify.sh                 curl smoke checks used by deploy and launch_demo  
│       └── sagemaker/                build_model.py, code/inference.py, deploy.sh (optional tier)  
├── apps/  
│   ├── citizen-app/                  Flutter web (entry lib/main_citizen.dart) — config/api.dart edited to contract  
│   ├── police-app/                   Flutter web (entry lib/main.dart)  
│   └── dashboard/                    React + Vite — src/config/api.js edited to contract  
├── ml/                               Rakshak_ML training scripts + v2 CSV (artifacts stay in S3)  
├── docs/                             AWS_RESOURCES.md (enumerated), API.md (frozen contract), RUNBOOK.md (demo)  
└── scripts/launch_demo.sh  
  
Lambda ownership (function name → routes):  
  
┌─────────────────────────┬────────────────┬───────────┬─────────────────────────────────────────────────────────────────────┬──────────────────────────────────────────────────────────┐  
│        Function         │ Memory/timeout │   Layer   │                          Routes (contract)                          │                   Legacy aliases kept                    │  
├─────────────────────────┼────────────────┼───────────┼─────────────────────────────────────────────────────────────────────┼──────────────────────────────────────────────────────────┤  
│                         │                │           │ POST /sos, GET /incident/{id}, GET /incident/{id}/eta, GET          │ /sos/live, /sos/dispatch/{id}, /sos/resolve/{id},        │  
│ rakshak-sos-handler     │ 256 MB / 30 s  │ none      │ /incidents/active, PATCH /incident/{id}/{accept,status,resolve}     │ /sos/cancelled, /police/sos/active,                      │  
│                         │                │           │                                                                     │ /police/sos/{sos_id}/status                              │  
├─────────────────────────┼────────────────┼───────────┼─────────────────────────────────────────────────────────────────────┼──────────────────────────────────────────────────────────┤  
│ rakshak-patrol-handler  │ 256 MB / 30 s  │ none      │ GET /dashboard/patrols                                              │ GET /patrols, PATCH /patrols/{id}/status, POST           │  
│                         │                │           │                                                                     │ /patrol/optimize                                         │  
├─────────────────────────┼────────────────┼───────────┼─────────────────────────────────────────────────────────────────────┼──────────────────────────────────────────────────────────┤  
│ rakshak-test-inference  │ 1024 MB / 30 s │ ml-layer  │ GET /prediction/{zone}                                              │ POST /predict, GET /prediction/zone/{zoneId}             │  
│                         │                │ v8        │                                                                     │                                                          │  
├─────────────────────────┼────────────────┼───────────┼─────────────────────────────────────────────────────────────────────┼──────────────────────────────────────────────────────────┤  
│ rakshak-dashboard       │ 1024 MB / 30 s │ ml-layer  │ GET /dashboard/{snapshot,timeline,heatmap}, GET /health, GET        │ GET /heatmap/live                                        │  
│                         │                │ v8        │ /version                                                            │                                                          │  
├─────────────────────────┼────────────────┼───────────┼─────────────────────────────────────────────────────────────────────┼──────────────────────────────────────────────────────────┤  
│ rakshak-reports-handler │ 256 MB / 30 s  │ none      │ — (extension)                                                       │ /reports/*                                               │  
├─────────────────────────┼────────────────┼───────────┼─────────────────────────────────────────────────────────────────────┼──────────────────────────────────────────────────────────┤  
│ citizen (recovered)     │ as found       │ as found  │ — (extension)                                                       │ POST /citizens/ping, GET /police/citizens/active, GET    │  
│                         │                │           │                                                                     │ /police/route                                            │  
├─────────────────────────┼────────────────┼───────────┼─────────────────────────────────────────────────────────────────────┼──────────────────────────────────────────────────────────┤  
│ removed                 │                │           │                                                                     │ rakshak-sos-feed, rakshak-score-refresh,                 │  
│                         │                │           │                                                                     │ rakshak-scan-inference                                   │  
└─────────────────────────┴────────────────┴───────────┴─────────────────────────────────────────────────────────────────────┴──────────────────────────────────────────────────────────┘  
  
Service boundaries: incidents.py is the only code that writes rakshak-sos-alerts and the only code that changes a patrol's assignment; patrols.py is the only code that computes positions; ml.py is the only code that touches the model; handlers are thin routers (method + path → function) with per-route validation. Every response passes through http.resp() which adds CORS, Cache-Control: no-store, generated_at, and emits one JSON log line {route, status, ms, request_id}.  
  
API flow (SOS): citizen POST /sos → validate → incidents.create() → patrols.assign_nearest() (conditional write) → events SOS Created / Patrol Assigned / En Route → 201. Police polls GET /incidents/active?patrol_id= (2 s) → PATCH /incident/{id}/accept → .../status {reached} (patrol → AtScene) → .../resolve (patrol → Returning → settles Patrolling on next read). Citizen polls GET /incident/{id} (2 s) for status + eta_seconds + patrol_position. Dashboard polls patrols 3 s, active 2 s, snapshot 5 s, timeline 5 s, heatmap 10 s.  
  
ML flow: §7 diagram. Patrol flow: §8 (compute-on-read, no scheduler). Dashboard flow: §9. Deployment flow: §11 (make deploy = deploy.py; SAM template optional later for greenfield accounts only — never applied to the live account).  
  
14. Implementation Priority (Top 10)  
  
1. Regain and record AWS truth. aws login (agent-toolkit), then enumerate: apigatewayv2 get-routes/get-integrations, lambda list-functions/get-function-configuration (architecture, layers, env — confirm IAM keys are gone), dynamodb list-tables/describe-table (all 8), iam policies on rakshak-lambda-role, s3 ls bucket, sagemaker list-endpoints. Write docs/AWS_RESOURCES.md. Download the zip of the Lambda serving /citizens/ping and commit it as functions/citizen/. Rotate/delete AKIA…7YPR.  
2. Restore real inference (P0 for the demo). Build rakshak-ml-layer v8 (numpy + scipy + xgboost-cpu 3.2.0 for the confirmed architecture); extract booster.json from sagemaker/model-v2-20260904.tar.gz and upload to models/v2/booster.json; implement ml.predict_batch with local tier first, circuit breaker, /tmp cache; env-gate SageMaker; unit-test against validation.json. Acceptance: 44/44 zones source=s3-model, /dashboard/heatmap < 0.5 s warm.  
3. One incident service. Move sos-feed logic into sos-handler behind incidents.transition(); add GET /incident/{id}, GET /incident/{id}/eta, PATCH /incident/{id}/accept (additive ack); register the contract routes plus legacy aliases; repoint /police/sos/* to sos-handler; delete rakshak-sos-feed.  
4. Contract completion. GET /dashboard/patrols → patrol-handler; GET /dashboard/heatmap alias; GET /prediction/{zone} on test-inference; GET /health (DDB describe + ML tier + version) and GET /version (from assets/version.json written at build) on dashboard. Retire /score/refresh + its Lambda.  
5. Idempotent deploy. deploy/deploy.py + routes.py + verify.sh + Makefile; account guard; log retention 14 d; prints rollback versions. Retire DEPLOY_COMMANDS.md to runbook status and the rakshak_aws_final/deploy scripts.  
6. Frontend contract migration (config-only). Update citizen-app/lib/config/api.dart, police-app/lib/config/api.dart, dashboard/src/config/api.js to contract paths; citizen polls GET /incident/{id} and renders eta_seconds/assigned_officer (currently discarded); police calls /accept before reached; dashboard TYPE_COLOR gets Accepted. Re-run the 16-step E2E.  
7. Patrol sim patches. Status whitelist on PATCH /patrols/{id}/status; seed clear_active uses release_patrol/settle; routes from assets/patrol_routes.json; settle inside snapshot/active reads; generated_at instead of stale updated_at.  
8. GSI status-created_at-index on rakshak-sos-alerts and switch active feed, resolved_today, timeline to Query; enrichment via batch_get_item for assigned patrols.  
9. Observability + warmers. Structured JSON log line in http.resp(), request id, latency; EventBridge 5-min warm rule for the four hot functions; one 5xx alarm per function; launch_demo.sh checks /health.  
10. Repo hygiene. git init at the new root; delete obsolete generations after step 1 recovery (rakshak-backend, Rakshak/, rakshak_aws_final/{lib,rakshak-dashboard,tests}, */deploy copies, CLAUDE.md ×3, hotfix scripts, score-refresh); dedupe GeoJSON to one copy; pin all requirements; rewrite README.md, API_ENDPOINTS.md, DEMO_READY.md to reflect this architecture. (P2, after the demo: single Flutter project with two entrypoints; API-key/Cognito auth; drop the redundant OPTIONS /{proxy+} route once native CORS is confirmed.)  
