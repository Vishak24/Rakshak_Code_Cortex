#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# RAKSHAK SIH 2026 — 100% React Web Architecture Demo Launcher
#   Citizen App       React/Vite PWA → http://localhost:3000
#   Police Patrol App React/Vite PWA → http://localhost:3001
#   Central Dashboard React/Vite     → http://localhost:3002
# All three talk to the deployed AWS backend.
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
  local url="$1" name="$2" tries="${3:-30}"
  for ((i=1; i<=tries; i++)); do
    if curl -sf -o /dev/null "$url"; then ok "$name healthy ($url)"; return 0; fi
    sleep 1
  done
  warn "$name did not become healthy at $url after $((tries))s (check $LOG_DIR)"
  return 1
}

# ── 1. dependencies ─────────────────────────────────────────────────────────
say "[1/7] Checking Node/npm dependencies for Web Apps"
command -v npm >/dev/null || die "npm not on PATH"

if [ ! -d "$ROOT/apps/citizen-web/node_modules" ]; then
  ( cd "$ROOT/apps/citizen-web" && npm install >"$LOG_DIR/citizen-npm.log" 2>&1 ) && ok "citizen-web deps" &
else
  ok "citizen-web deps (node_modules present)"
fi

if [ ! -d "$ROOT/apps/police-web/node_modules" ]; then
  ( cd "$ROOT/apps/police-web" && npm install >"$LOG_DIR/police-npm.log" 2>&1 ) && ok "police-web deps" &
else
  ok "police-web deps (node_modules present)"
fi

if [ ! -d "$ROOT/dashboard/node_modules" ]; then
  ( cd "$ROOT/dashboard" && npm install >"$LOG_DIR/dashboard-npm.log" 2>&1 ) && ok "dashboard deps" &
else
  ok "dashboard deps (node_modules present)"
fi
wait

# ── 2. free the ports ──────────────────────────────────────────────────────
say "[2/7] Freeing ports $CITIZEN_PORT / $POLICE_PORT / $DASH_PORT"
free_port $CITIZEN_PORT; free_port $POLICE_PORT; free_port $DASH_PORT

# ── 3. Citizen Web App ─────────────────────────────────────────────────────
say "[3/7] Starting Citizen Web App on :$CITIZEN_PORT"
( cd "$ROOT/apps/citizen-web" && exec npm run dev -- --port $CITIZEN_PORT --host \
) </dev/null >"$LOG_DIR/citizen.log" 2>&1 &
echo $! > "$LOG_DIR/citizen.pid"

# ── 4. Police Web App ──────────────────────────────────────────────────────
say "[4/7] Starting Police Patrol App on :$POLICE_PORT"
( cd "$ROOT/apps/police-web" && exec npm run dev -- --port $POLICE_PORT --host \
) </dev/null >"$LOG_DIR/police.log" 2>&1 &
echo $! > "$LOG_DIR/police.pid"

# ── 5. Central Dashboard ───────────────────────────────────────────────────
say "[5/7] Starting Central Dashboard on :$DASH_PORT"
( cd "$ROOT/dashboard" && exec npm run dev -- --port $DASH_PORT --host \
) </dev/null >"$LOG_DIR/dashboard.log" 2>&1 &
echo $! > "$LOG_DIR/dashboard.pid"

# ── 6. wait for health ─────────────────────────────────────────────────────
say "[6/7] Waiting for all web servers (React Vite dev servers land in ~1s)…"
wait_http "http://localhost:$CITIZEN_PORT" "Citizen Web App"  30
wait_http "http://localhost:$POLICE_PORT"  "Police Web App font" 30
wait_http "http://localhost:$DASH_PORT"    "Central Dashboard" 30

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

say "Pre-warming SOS + prediction Lambdas"
curl -s -o /dev/null "$API_BASE/sos/live?user_id=__warmup__" || true
curl -s -o /dev/null "$API_BASE/predict" -H 'Content-Type: application/json' \
  -d '{"pincode":"600017","hour":22}' || true
ok "Lambdas warm"

cat <<EOF

┌─────────────────────────────────────────────────────────────────┐
│  RAKSHAK DEMO — 100% REACT WEB ARCHITECTURE READY               │
├─────────────────────────────────────────────────────────────────┤
│  Citizen Web: http://localhost:$CITIZEN_PORT                              │
│  Police Web:  http://localhost:$POLICE_PORT                              │
│  Dashboard:   http://localhost:$DASH_PORT                              │
│                                                                 │
│  Backend API: $API_BASE
│  Region:      $AWS_REGION                                          │
├─────────────────────────────────────────────────────────────────┤
│  Logs:  $LOG_DIR
│  Stop:  kill \$(cat $LOG_DIR/*.pid)
└─────────────────────────────────────────────────────────────────┘
EOF

wait
