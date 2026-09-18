# `_legacy/` — recovered, deployed, but unreferenced

These three Lambdas exist live in the AWS account (`468704514492`, `ap-south-1`)
but are **not** wired to any route on API Gateway `aksdwfbnn5` as of 2026-09-18
(confirmed via `apigatewayv2 get-routes` — no route targets their integration).
Their source previously existed only in AWS, not in this repository; it was
recovered here (`lambda get-function` → download the deployment package) for
documentation and audit-trail purposes.

They are **not** built or redeployed by `build/build_zips.sh` or `deploy/`.

| Function | Operates on | Status |
|---|---|---|
| `rakshak-scan-inference` | Loads `rakshak_chennai_model.pkl` (the **v1** RandomForest, not the v2 XGBoost model) directly from S3 via `joblib`. Was wired to `POST /scan` — that route still exists and still works, but nothing in the three apps calls it. | orphaned route, live but unused |
| `rakshak-sos-dispatch` | Reads/writes the legacy `patrol_vehicles` / `sos_alerts` tables (not `rakshak-patrols` / `rakshak-sos-alerts`) | no route — unreachable |
| `rakshak-location-update` | Writes `patrol_vehicles` and `user_locations` (both distinct from the current `rakshak-patrols` / `rakshak-users` tables) | no route — unreachable |

Do not delete the underlying AWS resources (functions, `patrol_vehicles`,
`sos_alerts`, `user_locations` tables) without confirming nothing else in the
account depends on them — this audit found no route or caller, but that is a
point-in-time observation, not a guarantee.
