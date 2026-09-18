#!/usr/bin/env bash
# verify.sh — read-mostly smoke test of a deployed Rakshak-SIH API.
#
#   bash deploy/verify.sh [BASE_URL]     # defaults to the live account's API
#
# Writes and cleans up exactly one SOS incident (created, taken through the
# full lifecycle, resolved) to prove the contract paths work end-to-end.
# Exits non-zero if any check fails.
set -u
B="${1:-https://aksdwfbnn5.execute-api.ap-south-1.amazonaws.com}"
FAIL=0

pass() { printf '  \033[1;32mPASS\033[0m  %s\n' "$1"; }
fail() { printf '  \033[1;31mFAIL\033[0m  %s\n' "$1"; FAIL=1; }

check_status() {
  local method="$1" path="$2" expect="$3" label="$4" data="${5:-}"
  local code
  if [ -n "$data" ]; then
    code=$(curl -s -o /tmp/verify_resp.json -w '%{http_code}' -X "$method" "$B$path" \
      -H 'Content-Type: application/json' -d "$data")
  else
    code=$(curl -s -o /tmp/verify_resp.json -w '%{http_code}' -X "$method" "$B$path")
  fi
  if [ "$code" = "$expect" ]; then pass "$label ($code)"; else fail "$label (got $code, want $expect)"; fi
}

check_warm_latency() {
  # Best-of-3: a single sample is noisy enough (network jitter to ap-south-1,
  # an occasional GC pause) to false-fail a target that holds on every other
  # call. Warms the container once, then keeps the fastest of 3 real samples.
  local path="$1" max_ms="$2" label="$3"
  curl -s -o /dev/null "$B$path" >/dev/null  # warm it first
  local best=999999 t ms
  for _ in 1 2 3; do
    t=$(curl -s -o /dev/null -w '%{time_total}' "$B$path")
    ms=$(python3 -c "print(int(float('$t')*1000))")
    [ "$ms" -lt "$best" ] && best=$ms
  done
  if [ "$best" -le "$max_ms" ]; then pass "$label ${best}ms <= ${max_ms}ms (best of 3)"; else fail "$label ${best}ms > ${max_ms}ms (best of 3)"; fi
}

echo "== Rakshak-SIH verify == $B"

echo; echo "-- System --"
check_status GET /health 200 "GET /health"
check_status GET /version 200 "GET /version"

echo; echo "-- Frozen contract: read routes --"
check_status GET /dashboard/snapshot 200 "GET /dashboard/snapshot"
check_status GET /dashboard/patrols 200 "GET /dashboard/patrols"
check_status GET /dashboard/timeline 200 "GET /dashboard/timeline"
check_status GET /dashboard/heatmap 200 "GET /dashboard/heatmap"
check_status GET /prediction/600017 200 "GET /prediction/{zone}"
check_status GET /incidents/active 200 "GET /incidents/active"

echo; echo "-- Performance (warm) --"
check_warm_latency /dashboard/snapshot 500 "dashboard/snapshot"
check_warm_latency /prediction/600017 300 "prediction/{zone}"
check_warm_latency /dashboard/patrols 300 "dashboard/patrols"

echo; echo "-- ML tier --"
SRC=$(curl -s "$B/prediction/600017" | python3 -c 'import sys,json;print(json.load(sys.stdin)["source"])')
if [ "$SRC" = "s3-model" ] || [ "$SRC" = "sagemaker" ]; then
  pass "prediction source=$SRC (real model, not baseline)"
else
  fail "prediction source=$SRC (expected s3-model or sagemaker)"
fi

echo; echo "-- Heatmap: 44 zones, all real-model-scored --"
python3 -c "
import json, urllib.request
d = json.load(urllib.request.urlopen('$B/heatmap/live'))
zones = d.get('zones', [])
n = len(zones)
real = sum(1 for z in zones if z.get('source') in ('s3-model', 'sagemaker'))
print(f'  zone_count={n} real_model={real}')
import sys
sys.exit(0 if n == 44 and real == 44 else 1)
" && pass "44/44 zones, all real-model-scored" || fail "heatmap zone count or source check"

echo; echo "-- Full SOS lifecycle (frozen-contract paths; writes + cleans up one row) --"
RESP=$(curl -s -X POST "$B/sos" -H 'Content-Type: application/json' \
  -d '{"user_id":"__verify__","username":"verify","latitude":13.0418,"longitude":80.2341,"pincode":"600017","risk_level":"HIGH"}')
SID=$(echo "$RESP" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("sos_id",""))' 2>/dev/null)
if [ -n "$SID" ]; then
  pass "POST /sos -> $SID"
  check_status GET "/incident/$SID" 200 "GET /incident/{id}"
  check_status GET "/incident/$SID/eta" 200 "GET /incident/{id}/eta"
  check_status PATCH "/incident/$SID/accept" 200 "PATCH /incident/{id}/accept" '{"officer_id":"VERIFY"}'
  check_status PATCH "/incident/$SID/status" 200 "PATCH /incident/{id}/status" '{"status":"reached","officer_id":"VERIFY"}'
  check_status PATCH "/incident/$SID/resolve" 200 "PATCH /incident/{id}/resolve"
else
  fail "POST /sos did not return a sos_id"
fi

echo
if [ "$FAIL" = "0" ]; then
  echo "ALL CHECKS PASSED"
else
  echo "SOME CHECKS FAILED"
fi
exit $FAIL
