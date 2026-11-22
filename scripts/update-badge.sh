#!/usr/bin/env bash
# Regenerate badge.svg from this repo's README using the action's own scoring.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
out="$(mktemp)"
trap 'rm -f "$out"' EXIT
INPUT_REPO= INPUT_THRESHOLD=0 GITHUB_WORKSPACE="$ROOT" GITHUB_REPOSITORY= \
  GITHUB_OUTPUT="$out" bash "$ROOT/.github/actions/vitals/entrypoint.sh" >/dev/null
sed -n 's/^badge_svg=//p' "$out" > "$ROOT/badge.svg"
echo "updated $ROOT/badge.svg"
