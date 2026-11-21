#!/usr/bin/env bash
set -euo pipefail

# --- Inputs ---
REPO="${INPUT_REPO:-}"
THRESHOLD="${INPUT_THRESHOLD:-6}"

WORKDIR=""
cleanup() { if [ -n "$WORKDIR" ]; then rm -rf "$WORKDIR"; fi; }
trap cleanup EXIT

# --- Resolve source directory ---
if [ -z "$REPO" ]; then
  SRC="${GITHUB_WORKSPACE:-$PWD}"
else
  WORKDIR=$(mktemp -d)
  git clone "https://github.com/${REPO}.git" "$WORKDIR" 2>/dev/null || {
    echo "::error ::Failed to clone repository: ${REPO}"
    exit 1
  }
  SRC="$WORKDIR"
fi

# --- Read README ---
if [ -f "$SRC/README.md" ]; then
  README="$SRC/README.md"
elif [ -f "$SRC/readme.md" ]; then
  README="$SRC/readme.md"
else
  echo "::error ::No README found in ${REPO:-$SRC}"
  exit 1
fi

# --- Scoring (7 checks, one point each) ---
SCORE=0

# 1. Title/description (first line or H1)
TITLE=$(head -1 "$README" | sed 's/^# //' | sed 's/^## //')
if [ -n "$TITLE" ]; then
  SCORE=$((SCORE + 1))
fi

# 2. Badges check (look for common badge patterns)
BADGE_COUNT=$(grep -rohE '!\[[^]]*\]\([^)]*\.(svg|png|gif)' "$README" 2>/dev/null | wc -l || true)
if [ "$BADGE_COUNT" -ge 1 ]; then
  SCORE=$((SCORE + 1))
fi

# 3. License check
if grep -qiE 'license|mit|apache|gpl' "$README" 2>/dev/null; then
  SCORE=$((SCORE + 1))
fi

# 4. Code of conduct check
if grep -qiE 'code of conduct|conduct' "$README" 2>/dev/null; then
  SCORE=$((SCORE + 1))
fi

# 5. Links check (basic: no empty markdown links like []())
EMPTY_LINKS=$(grep -oF ']()' "$README" 2>/dev/null | wc -l || true)
if [ "$EMPTY_LINKS" -eq 0 ]; then
  SCORE=$((SCORE + 1))
fi

# 6. word about contribution or contributing
if grep -qiE 'contributing|contribute' "$README" 2>/dev/null; then
  SCORE=$((SCORE + 1))
fi

# 7. Basic front matter or overview
if head -5 "$README" | grep -qiE 'purpose|description|overview'; then
  SCORE=$((SCORE + 1))
fi

# --- Badge SVG generation (score out of 7) ---
BADGE_SVG="<svg xmlns='http://www.w3.org/2000/svg' width='80' height='20' role='img' aria-label='README Score: ${SCORE}/7'><rect width='80' height='20' rx='3' fill='#eeeeee'/><text x='4' y='15' fill='#333333' font-size='11' font-family='DejaVu Sans,Verdana,Geneva,sans-serif'>Score: ${SCORE}/7</text></svg>"

# --- Output ---
echo "score=${SCORE}" >> "$GITHUB_OUTPUT"
echo "badge_svg=${BADGE_SVG}" >> "$GITHUB_OUTPUT"

# --- Optional failure ---
if [ "$SCORE" -lt "$THRESHOLD" ]; then
  echo "::warning ::README score ${SCORE}/7 is below threshold ${THRESHOLD}. Consider improving your README."
fi
