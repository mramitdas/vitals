#!/usr/bin/env bash
set -euo pipefail

# --- Inputs ---
REPO="${INPUT_REPO:-}"
THRESHOLD="${INPUT_THRESHOLD:-6}"
GITHUB_OUTPUT="${GITHUB_OUTPUT:-/dev/stdout}"

if ! printf '%s' "$THRESHOLD" | grep -qE '^[0-7]$'; then
  echo "::error ::threshold must be a whole number from 0 to 7 (got '${THRESHOLD}')."
  exit 1
fi

WORKDIR=""
cleanup() { if [ -n "$WORKDIR" ]; then rm -rf "$WORKDIR"; fi; }
trap cleanup EXIT

# --- Resolve source directory ---
if [ -z "$REPO" ]; then
  SRC="${GITHUB_WORKSPACE:-$PWD}"
elif [ -n "${GITHUB_REPOSITORY:-}" ] && [ "$REPO" = "$GITHUB_REPOSITORY" ]; then
  SRC="${GITHUB_WORKSPACE:-$PWD}"
else
  if ! printf '%s' "$REPO" | grep -qE '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$'; then
    echo "::error ::Invalid repo '${REPO}'. Use owner/repo."
    exit 1
  fi
  WORKDIR=$(mktemp -d)
  # shortcut: cross-repo clone uses public HTTPS; private repos need a token
  git clone --depth 1 "https://github.com/${REPO}.git" "$WORKDIR" || {
    echo "::error ::Failed to clone repository: ${REPO}"
    exit 1
  }
  SRC="$WORKDIR"
fi

if [ ! -d "$SRC" ]; then
  echo "::error ::Source directory not found: ${SRC}"
  exit 1
fi

# --- Read README (case-insensitive name) ---
README=$(find "$SRC" -maxdepth 1 -type f -iname 'readme*' 2>/dev/null | sort | head -1 || true)
if [ -z "$README" ]; then
  echo "::error ::No README found in ${REPO:-$SRC}"
  exit 1
fi

# --- Scoring (7 checks, one point each) ---
SCORE=0

# 1. Title/description: first non-empty line is text or a heading, not a bare image/link
FIRST_LINE=$(grep -m1 -v '^[[:space:]]*$' "$README" || true)
TITLE=$(printf '%s' "$FIRST_LINE" | sed -E 's/^#+[[:space:]]*//')
if [ -n "$TITLE" ] \
  && ! printf '%s' "$FIRST_LINE" | grep -qE '^[[:space:]]*!?\[' \
  && printf '%s' "$TITLE" | grep -qE '[A-Za-z0-9]'; then
  SCORE=$((SCORE + 1))
fi

# 2. Badges: any markdown image (covers .svg/.png and extensionless shields.io URLs)
BADGE_COUNT=$(grep -rohE '!\[[^]]*\]\([^)]*\)' "$README" 2>/dev/null | wc -l || true)
if [ "$BADGE_COUNT" -ge 1 ]; then
  SCORE=$((SCORE + 1))
fi

# 3. License (whole words, so "commit"/"submit" do not count)
if grep -qiE 'license|(^|[^a-z])mit([^a-z]|$)|apache|gpl' "$README" 2>/dev/null; then
  SCORE=$((SCORE + 1))
fi

# 4. Code of conduct (whole word, so "conducted" does not count)
if grep -qiE 'code of conduct|(^|[^a-z])conduct([^a-z]|$)' "$README" 2>/dev/null; then
  SCORE=$((SCORE + 1))
fi

# 5. Links: no empty markdown links like []()
EMPTY_LINKS=$(grep -oF ']()' "$README" 2>/dev/null | wc -l || true)
if [ "$EMPTY_LINKS" -eq 0 ]; then
  SCORE=$((SCORE + 1))
fi

# 6. Contribution or contributing
if grep -qiE 'contributing|contribute' "$README" 2>/dev/null; then
  SCORE=$((SCORE + 1))
fi

# 7. Purpose/description in the first five lines
if head -5 "$README" | grep -qiE 'purpose|description|overview'; then
  SCORE=$((SCORE + 1))
fi

# --- Badge SVG generation (score out of 7) ---
if [ "$SCORE" -ge 6 ]; then
  SCORE_COLOR="#4c1"
  SCORE_TEXT="#ffffff"
elif [ "$SCORE" -ge 4 ]; then
  SCORE_COLOR="#dfb317"
  SCORE_TEXT="#333333"
else
  SCORE_COLOR="#e05d44"
  SCORE_TEXT="#ffffff"
fi
BADGE_SVG="<svg xmlns='http://www.w3.org/2000/svg' width='100' height='20' role='img' aria-label='Vitals README score: ${SCORE}/7'><title>Vitals: ${SCORE}/7</title><rect width='100' height='20' rx='3' fill='#555'/><path d='M52 0h45a3 3 0 0 1 3 3v14a3 3 0 0 1-3 3H52z' fill='${SCORE_COLOR}'/><text x='26' y='14' text-anchor='middle' fill='#ffffff' font-size='11' font-family='DejaVu Sans,Verdana,Geneva,sans-serif'>vitals</text><text x='76' y='14' text-anchor='middle' fill='${SCORE_TEXT}' font-size='11' font-family='DejaVu Sans,Verdana,Geneva,sans-serif'>${SCORE}/7</text></svg>"

# --- Output ---
echo "score=${SCORE}" >> "$GITHUB_OUTPUT"
echo "badge_svg=${BADGE_SVG}" >> "$GITHUB_OUTPUT"

# --- Fail below threshold ---
if [ "$SCORE" -lt "$THRESHOLD" ]; then
  echo "::error ::README score ${SCORE}/7 is below threshold ${THRESHOLD}."
  exit 1
fi
echo "::notice ::README score ${SCORE}/7 meets threshold ${THRESHOLD}."
