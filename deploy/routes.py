"""
routes.py — the single source of truth mapping API route -> Lambda function.

Used by deploy.py to create/verify every route on API aksdwfbnn5. Split into
CONTRACT (the frozen contract this build implements) and LEGACY (routes that
existed before this pass and stay live so the three apps keep working without
a redeploy — see README.md "What changed and why").

rakshak-sos-feed was merged into rakshak-sos-handler (same shared module, no
cross-Lambda dependency, and the task's target function list has no separate
feed Lambda) — every route that used to target it now targets
rakshak-sos-handler instead. rakshak-score-refresh was retired: it served a
legacy dashboard hook (`useRiskData.js` POST /score/refresh) that the current
dashboard no longer calls (it polls GET /heatmap/live instead) — confirmed no
caller before removal.
"""

CONTRACT = [
    # Citizen
    ("POST",  "/sos",                          "rakshak-sos-handler"),
    ("GET",   "/incident/{id}",                 "rakshak-sos-handler"),
    ("GET",   "/incident/{id}/eta",              "rakshak-sos-handler"),
    # Police
    ("GET",   "/incidents/active",              "rakshak-sos-handler"),
    ("PATCH", "/incident/{id}/accept",           "rakshak-sos-handler"),
    ("PATCH", "/incident/{id}/status",           "rakshak-sos-handler"),
    ("PATCH", "/incident/{id}/resolve",          "rakshak-sos-handler"),
    # Dashboard
    ("GET",   "/dashboard/snapshot",            "rakshak-dashboard"),
    ("GET",   "/dashboard/patrols",             "rakshak-patrol-handler"),
    ("GET",   "/dashboard/timeline",            "rakshak-dashboard"),
    ("GET",   "/dashboard/heatmap",             "rakshak-dashboard"),
    # Prediction
    ("GET",   "/prediction/{zone}",             "rakshak-dashboard"),
    ("POST",  "/predict",                       "rakshak-test-inference"),
    # System
    ("GET",   "/health",                        "rakshak-dashboard"),
    ("GET",   "/version",                       "rakshak-dashboard"),
]

# Pre-existing routes, kept live as-is so citizen-app / police-app / dashboard
# keep working unmodified until their configs are migrated to CONTRACT paths.
LEGACY = [
    ("POST",  "/sos/live",                      "rakshak-sos-handler"),
    ("GET",   "/sos/live",                      "rakshak-sos-handler"),
    ("POST",  "/sos/dispatch/{id}",             "rakshak-sos-handler"),
    ("PATCH", "/sos/resolve/{id}",              "rakshak-sos-handler"),
    ("POST",  "/sos/cancelled",                 "rakshak-sos-handler"),
    ("GET",   "/police/sos/active",             "rakshak-sos-handler"),
    ("PATCH", "/police/sos/{sos_id}/status",    "rakshak-sos-handler"),
    ("GET",   "/patrols",                       "rakshak-patrol-handler"),
    ("PATCH", "/patrols/{id}/status",           "rakshak-patrol-handler"),
    ("POST",  "/patrol/optimize",               "rakshak-patrol-handler"),
    ("GET",   "/heatmap/live",                  "rakshak-dashboard"),
    ("GET",   "/prediction/zone/{zoneId}",      "rakshak-dashboard"),
    ("GET",   "/reports",                       "rakshak-reports-handler"),
    ("POST",  "/reports/submit",                "rakshak-reports-handler"),
    ("PATCH", "/reports/approve/{id}",          "rakshak-reports-handler"),
    ("PATCH", "/reports/reject/{id}",           "rakshak-reports-handler"),
    ("GET",   "/police/citizens/active",        "rakshak-night-monitor"),
    ("POST",  "/citizens/ping",                 "rakshak-night-monitor"),
    ("GET",   "/police/route",                  "rakshak-routing"),
    ("POST",  "/scan",                          "rakshak-scan-inference"),
]

ALL_ROUTES = CONTRACT + LEGACY

# Functions this deploy tool builds, ships code for, and (for the ML ones)
# attaches the ML layer to. rakshak-scan-inference is orphaned and stays
# unmanaged (see lambdas/_legacy/README.md).
MANAGED_FUNCTIONS = [
    "rakshak-sos-handler",
    "rakshak-patrol-handler",
    "rakshak-reports-handler",
    "rakshak-test-inference",
    "rakshak-dashboard",
    "rakshak-night-monitor",
    "rakshak-routing",
]
ML_FUNCTIONS = ["rakshak-test-inference", "rakshak-dashboard"]
