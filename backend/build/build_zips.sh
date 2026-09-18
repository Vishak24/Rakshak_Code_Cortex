#!/usr/bin/env bash
# Build deployable zips for every Rakshak-SIH Lambda.
#
#   bash build/build_zips.sh
#
# Output: build/dist/<function-name>.zip
# Each zip contains: lambda_function.py + rakshak_common.py + chennai_zones.geojson
# (the shared module is vendored into every bundle — no Lambda layer needed for it).

set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SHARED="$ROOT/lambdas/_shared"
DIST="$ROOT/build/dist"
rm -rf "$DIST"; mkdir -p "$DIST"

FUNCS=(
  rakshak-sos-handler
  rakshak-patrol-handler
  rakshak-reports-handler
  rakshak-test-inference
  rakshak-dashboard
  rakshak-night-monitor
  rakshak-routing
)

for fn in "${FUNCS[@]}"; do
  SRC="$ROOT/lambdas/$fn"
  STAGE="$(mktemp -d)"
  cp "$SRC/lambda_function.py"        "$STAGE/"
  cp "$SHARED/rakshak_common.py"      "$STAGE/"
  cp "$SHARED/chennai_zones.geojson"  "$STAGE/"
  # Reproducible build: zip embeds each entry's mtime, so two builds of
  # byte-identical source otherwise produce different zip bytes -> a different
  # CodeSha256 -> deploy.py's "code unchanged, skip" check never fires, and
  # every `make deploy` re-publishes a Lambda version even with no real change.
  # Pin every entry to a fixed time so identical source -> identical zip.
  find "$STAGE" -exec touch -t 202601010000 {} +
  ( cd "$STAGE" && TZ=UTC zip -qrX "$DIST/$fn.zip" . )
  rm -rf "$STAGE"
  printf '  %-24s -> build/dist/%s.zip  (%s)\n' "$fn" "$fn" "$(du -h "$DIST/$fn.zip" | cut -f1)"
done

echo "done. $(ls -1 "$DIST" | wc -l | tr -d ' ') zips in build/dist/"
