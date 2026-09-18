#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# RAKSHAK SIH 2026 — one-shot local demo launcher
#   Citizen App       Flutter web  → http://localhost:3000
#   Police Patrol App Flutter web  → http://localhost:3001
#   Central Dashboard Vite/React   → http://localhost:3002
# All three talk to the deployed AWS backend. No backend runs locally.
# ─────────────────────────────────────────────────────────────────────────────
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
API_BASE="https://aksdwfbnn5.execute-api.ap-south-1.amazonaws.com"
AWS_REGION="ap-south-1"
LOG_DIR="${ROOT}/.demo-logs"
mkdir -p "$LOG_DIR"

CITIZEN_PORT=3000
POLICE_PORT=3001
DASH_PORT=3002

say()  { printf '\033[1;36m%s\033[0m\n' "$*"; }
ok()   { printf '\033[1;32m  ✔ %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m  ! %s\033[0m\n' "$*"; }
die()  { printf '\033[1;31m  x %s\033[0m\n' "$*"; exit 1; }

free_port() {
  local p="$1"
  local pids
  pids="$(lsof -ti tcp:"$p" 2>/dev/null || true)"
  [ -n "$pids" ] && { warn "port $p busy — killing $pids"; kill $pids 2>/dev/null; sleep 1; }
}

wait_http() {
  local url="$1" name="$2" tries="${3:-120}"
  for ((i=1; i<=tries; i++)); do
    if curl -sf -o /dev/null "$url"; then ok "$name healthy ($url)"; return 0; fi
    sleep 2
  done
  warn "$name did not become healthy at $url after $((tries*2))s (check $LOG_DIR)"
  return 1
}

# ── 1. dependencies ─────────────────────────────────────────────────────────
say "[1/7] Checking dependencies"
command -v flutter >/dev/null || die "flutter not on PATH"
command -v npm     >/dev/null || die "npm not on PATH"

( cd "$ROOT/citizen-app" && flutter pub get >"$LOG_DIR/citizen-pubget.log" 2>&1 ) && ok "citizen-app deps" &
( cd "$ROOT/police-app"  && flutter pub get >"$LOG_DIR/police-pubget.log"  2>&1 ) && ok "police-app deps" &
if [ ! -d "$ROOT/dashboard/node_modules" ]; then
  ( cd "$ROOT/dashboard" && npm install >"$LOG_DIR/dashboard-npm.log" 2>&1 ) && ok "dashboard deps" &
else
  ok "dashboard deps (node_modules present)"
fi
wait

# ── 2. free the ports ──────────────────────────────────────────────────────
say "[2/7] Freeing ports $CITIZEN_PORT / $POLICE_PORT / $DASH_PORT"
free_port $CITIZEN_PORT; free_port $POLICE_PORT; free_port $DASH_PORT

# ── 3. Citizen App ─────────────────────────────────────────────────────────
say "[3/7] Starting Citizen App on :$CITIZEN_PORT"
( cd "$ROOT/citizen-app" && exec flutter run \
    -d web-server --web-hostname 0.0.0.0 --web-port $CITIZEN_PORT \
    -t lib/main_citizen.dart \
    --dart-define=API_BASE_URL=$API_BASE \
    --dart-define=AWS_REGION=$AWS_REGION \
) </dev/null >"$LOG_DIR/citizen.log" 2>&1 &
echo $! > "$LOG_DIR/citizen.pid"

# ── 4. Police App ──────────────────────────────────────────────────────────
say "[4/7] Starting Police Patrol App on :$POLICE_PORT"
( cd "$ROOT/police-app" && exec flutter run \
    -d web-server --web-hostname 0.0.0.0 --web-port $POLICE_PORT \
    -t lib/main.dart \
    --dart-define=API_BASE_URL=$API_BASE \
    --dart-define=AWS_REGION=$AWS_REGION \
) </dev/null >"$LOG_DIR/police.log" 2>&1 &
echo $! > "$LOG_DIR/police.pid"

# ── 5. Central Dashboard ───────────────────────────────────────────────────
say "[5/7] Starting Central Dashboard on :$DASH_PORT"
( cd "$ROOT/dashboard" && exec npm run dev -- --port $DASH_PORT --strictPort \
) </dev/null >"$LOG_DIR/dashboard.log" 2>&1 &
echo $! > "$LOG_DIR/dashboard.pid"

# ── 6. wait for health ─────────────────────────────────────────────────────
say "[6/7] Waiting for all servers (Flutter first build can take 1–3 min)…"
wait_http "http://localhost:$DASH_PORT"                "Central Dashboard" 120
wait_http "http://localhost:$CITIZEN_PORT"             "Citizen App"       180
wait_http "http://localhost:$POLICE_PORT"              "Police Patrol App" 180

# ── 7. backend health check ────────────────────────────────────────────────
say "[7/7] Backend health check"
hc() {
  local path="$1" label="$2" jqtest="$3"
  local body code
  body="$(curl -s -w $'\n%{http_code}' "$API_BASE$path")"
  code="$(printf '%s' "$body" | tail -n1)"
  body="$(printf '%s' "$body" | sed '$d')"
  if [ "$code" = "200" ] && printf '%s' "$body" | python3 -c "import sys,json;d=json.load(sys.stdin);sys.exit(0 if ($jqtest) else 1)" 2>/dev/null; then
    ok "$label  (HTTP 200)"
  else
    warn "$label  (HTTP $code)"
  fi
}
hc "/patrols"              "API Gateway / patrols"      "isinstance(d,list) and len(d)==20"
hc "/dashboard/snapshot"   "DynamoDB / snapshot"        "d['patrols']['total']>=1"
hc "/dashboard/timeline"   "Timeline"                   "isinstance(d,(list,dict))"
hc "/heatmap/live"         "Heatmap"                    "isinstance(d,(list,dict))"
hc "/police/sos/active"    "SOS feed"                   "isinstance(d,(list,dict))"
hc "/prediction/zone/600001" "SageMaker prediction"     "d.get('source')=='sagemaker'"

# The board must open with an empty incident feed — judges read a stale
# "6 dispatched / 0 responding" board as a broken system.
active_n="$(curl -s "$API_BASE/police/sos/active" \
  | python3 -c "import sys,json;print(len(json.load(sys.stdin)))" 2>/dev/null || echo '?')"
if [ "$active_n" = "0" ]; then
  ok "Incident feed is clean (0 active)"
else
  warn "Incident feed has $active_n active incident(s) — resolve them before judging:"
  warn "  curl -s '$API_BASE/police/sos/active' | python3 -c \"import sys,json;[print(i['sos_id']) for i in json.load(sys.stdin)]\""
  warn "  then PATCH $API_BASE/police/sos/<id>/status -d '{\"status\":\"resolved\"}'"
fi

# Pre-warm the SOS Lambda. A cold container adds ~3s to the first POST /sos/live,
# which on demo day is the judges' SOS press. Warm, it lands in ~0.2s.
say "Pre-warming SOS + prediction Lambdas"
curl -s -o /dev/null "$API_BASE/sos/live?user_id=__warmup__" || true
curl -s -o /dev/null "$API_BASE/predict" -H 'Content-Type: application/json' \
  -d '{"pincode":"600017","hour":22}' || true
ok "Lambdas warm"

cat <<EOF

┌─────────────────────────────────────────────────────────────────┐
│  RAKSHAK DEMO — READY                                            │
├─────────────────────────────────────────────────────────────────┤
│  Citizen:     http://localhost:$CITIZEN_PORT                              │
│  Police:      http://localhost:$POLICE_PORT                              │
│  Dashboard:   http://localhost:$DASH_PORT                              │
│  Healthcheck: http://localhost:$DASH_PORT/demo/healthcheck/              │
│                                                                 │
│  Backend API: $API_BASE
│  SageMaker:   Connected (prediction source=sagemaker)            │
│  Region:      $AWS_REGION                                          │
├─────────────────────────────────────────────────────────────────┤
│  Logs:  $LOG_DIR
│  Stop:  kill \$(cat $LOG_DIR/*.pid)
└─────────────────────────────────────────────────────────────────┘
EOF

wait
