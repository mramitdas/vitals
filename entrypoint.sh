#!/usr/bin/env bash
set -euo pipefail

# --- Inputs ---
REPO="${INPUT_REPO:-}"
THRESHOLD="${INPUT_THRESHOLD:-6}"
TOKEN="${INPUT_TOKEN:-}"
GITHUB_OUTPUT="${GITHUB_OUTPUT:-/dev/stdout}"

if ! printf '%s' "$THRESHOLD" | grep -qE '^[0-7]$'; then
  echo "::error ::threshold must be a whole number from 0 to 7 (got '${THRESHOLD}')."
  exit 1
fi

WORKDIR=""
cleanup() { if [ -n "$WORKDIR" ]; then rm -rf "$WORKDIR"; fi; }
trap cleanup EXIT

# --- Resolve source directory ---
REPO_LOWER=$(printf '%s' "$REPO" | tr '[:upper:]' '[:lower:]')
GH_LOWER=$(printf '%s' "${GITHUB_REPOSITORY:-}" | tr '[:upper:]' '[:lower:]')
if [ -z "$REPO" ]; then
  SRC="${GITHUB_WORKSPACE:-$PWD}"
elif [ -n "$REPO_LOWER" ] && [ "$REPO_LOWER" = "$GH_LOWER" ]; then
  SRC="${GITHUB_WORKSPACE:-$PWD}"
else
  if ! printf '%s' "$REPO" | grep -qE '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$'; then
    echo "::error ::Invalid repo '${REPO}'. Use owner/repo."
    exit 1
  fi
  WORKDIR=$(mktemp -d)
  if [ -n "$TOKEN" ]; then
    CLONE_URL="https://x-access-token:${TOKEN}@github.com/${REPO}.git"
  else
    CLONE_URL="https://github.com/${REPO}.git"
  fi
  GIT_TERMINAL_PROMPT=0 git clone --depth 1 "$CLONE_URL" "$WORKDIR" || {
    echo "::error ::Failed to clone ${REPO}. Private repos need the 'token' input."
    exit 1
  }
  SRC="$WORKDIR"
fi

if [ ! -d "$SRC" ]; then
  echo "::error ::Source directory not found: ${SRC}"
  exit 1
fi

# --- Read README (prefer README.md, then README, then any readme*) ---
README=$(find "$SRC" -maxdepth 1 -type f -iname 'readme.md' 2>/dev/null | sort | head -1 || true)
if [ -z "$README" ]; then
  README=$(find "$SRC" -maxdepth 1 -type f -iname 'readme' 2>/dev/null | sort | head -1 || true)
fi
if [ -z "$README" ]; then
  README=$(find "$SRC" -maxdepth 1 -type f -iname 'readme*' 2>/dev/null | sort | head -1 || true)
fi
if [ -z "$README" ]; then
  echo "::error ::No README found in ${REPO:-$SRC}"
  exit 1
fi

# Content outside fenced code blocks and inline code spans.
# Handles nested fence lengths (a 3-backtick line inside a 4-backtick fence).
# shortcut: 4-space indented code blocks are still scored; upgrade if needed.
BODY=$(awk '
{
  if (match($0, /^[[:space:]]*(```+|~~~+)/)) {
    s = substr($0, RSTART, RLENGTH)
    sub(/^[[:space:]]+/, "", s)
    c = substr(s, 1, 1)
    n = 0
    while (substr(s, n + 1, 1) == c) n++
    if (infence == 0) { infence = 1; flen = n; fchar = c }
    else if (c == fchar && n >= flen) { infence = 0; flen = 0; fchar = "" }
    next
  }
  if (infence == 0) print
}' "$README" | sed -E 's/`[^`]*`//g')

# --- Scoring (7 checks, one point each) ---
SCORE=0
FAILED=""
mark_fail() { FAILED="${FAILED}${FAILED:+, }$1"; }

clean_line() {
  printf '%s' "$1" | sed -E \
    -e 's/<!--.*-->//g' \
    -e 's/<[^>]*>//g' \
    -e 's/!\[[^]]*\]\([^)]*\)//g' \
    -e 's/^#+[[:space:]]*//' \
    -e 's/^[[:space:]]+//' \
    -e 's/[[:space:]]+$//'
}

# 1. Title/description: first meaningful line is text or a heading.
# A pure-image first line only passes if the next line is a heading.
FIRST=$(printf '%s\n' "$BODY" | grep -vE '^[[:space:]]*$' | sed -n '1p' || true)
SECOND=$(printf '%s\n' "$BODY" | grep -vE '^[[:space:]]*$' | sed -n '2p' || true)
TITLE=$(clean_line "$FIRST")
case "$TITLE" in
  *[A-Za-z0-9]*) ;;
  *)
    if printf '%s' "$SECOND" | grep -qE '^[[:space:]]*(#|<h[1-6])'; then
      TITLE=$(clean_line "$SECOND")
    else
      TITLE=""
    fi
    ;;
esac
if [ -n "$TITLE" ] && printf '%s' "$TITLE" | grep -qE '[A-Za-z0-9]'; then
  SCORE=$((SCORE + 1))
else
  mark_fail "title"
fi

# 2. Badges: markdown/HTML/reference image that looks like a badge (not a screenshot).
# Nested parentheses are allowed in URLs; multiple badges on one line are counted separately.
IMAGES=$(printf '%s\n' "$BODY" | grep -oiE '!\[[^]]*\]\(([^()]|\([^()]*\))*\)|<img[^>]*>|!\[[^]]*\]\[[^]]*\]' || true)
BADGE_COUNT=$(printf '%s\n' "$IMAGES" | grep -icE '\.svg|badge|shields|badgen|coveralls|codecov|/workflows/|/actions/|build|status' || true)
if [ "$BADGE_COUNT" -ge 1 ]; then
  SCORE=$((SCORE + 1))
else
  mark_fail "badges"
fi

# 3. License: a License heading, a whole-word license name, or a LICENSE file.
LICENSE_FILE=$(find "$SRC" -maxdepth 1 -type f \( -iname 'license*' -o -iname 'licence*' -o -iname 'copying*' \) 2>/dev/null | head -1 || true)
if printf '%s\n' "$BODY" | grep -qiE '^#{1,6}[[:space:]].*(license|licence)|(^|[^a-z])mit([^a-z]|$)|(^|[^a-z])apache([^a-z]|$)|(^|[^a-z])gpl([^a-z]|$)' \
  || [ -n "$LICENSE_FILE" ]; then
  SCORE=$((SCORE + 1))
else
  mark_fail "license"
fi

# 4. Code of conduct: phrase or whole word, ignoring negated mentions.
COC=$(printf '%s\n' "$BODY" | grep -iE 'code of conduct|(^|[^a-z])conduct([^a-z]|$)' \
  | grep -viE '(^|[^a-z])(no|not|without|never)([^a-z]|$).*(code of conduct|conduct)' || true)
COC_FILE=$(find "$SRC" -maxdepth 1 -type f -iname 'code_of_conduct*' 2>/dev/null | head -1 || true)
if [ -n "$COC" ] || [ -n "$COC_FILE" ]; then
  SCORE=$((SCORE + 1))
else
  mark_fail "code of conduct"
fi

# 5. Links: at least one link (markdown, reference, or autolink) and none empty.
LINKS=$(printf '%s\n' "$BODY" | grep -oE '(^|[^!])(\[[^]]*\]\(([^()]|\([^()]*\))*\)|\[[^]]+\]\[[^]]+\])|<https?://[^>]+>' || true)
LINK_COUNT=$(printf '%s\n' "$LINKS" | grep -c '[^[:space:]]' || true)
EMPTY_LINKS=$(printf '%s\n' "$LINKS" | grep -cE '\]\([[:space:]]*\)|\]\([[:space:]]*#[[:space:]]*\)' || true)
if [ "$LINK_COUNT" -ge 1 ] && [ "$EMPTY_LINKS" -eq 0 ]; then
  SCORE=$((SCORE + 1))
else
  mark_fail "links"
fi

# 6. Contributing: ignore negated mentions such as "Do not contribute".
CONTRIB=$(printf '%s\n' "$BODY" | grep -iE 'contributing|contribute' \
  | grep -viE '(^|[^a-z])(no|not|without|never|don.t|do not)([^a-z]|$).*contribut' || true)
if [ -n "$CONTRIB" ]; then
  SCORE=$((SCORE + 1))
else
  mark_fail "contributing"
fi

# 7. Purpose/description: a keyword in the first ten lines, or a prose sentence.
PURPOSE=0
PURPOSE_HEAD=$(printf '%s\n' "$BODY" | head -10)
if printf '%s\n' "$PURPOSE_HEAD" | grep -qiE 'purpose|description|overview'; then
  PURPOSE=1
elif printf '%s\n' "$PURPOSE_HEAD" | grep -vE '^[[:space:]]*(#|!\[|\[|<|>)' | grep -vE '^[[:space:]]*$' \
  | awk 'NF >= 4 { found = 1 } END { exit(found ? 0 : 1) }'; then
  PURPOSE=1
fi
if [ "$PURPOSE" -eq 1 ]; then
  SCORE=$((SCORE + 1))
else
  mark_fail "purpose"
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

# --- Output (multiline-safe) ---
{
  echo "score=${SCORE}"
  echo "badge_svg<<VITALS_EOF"
  echo "${BADGE_SVG}"
  echo "VITALS_EOF"
} >> "$GITHUB_OUTPUT"

# --- Fail below threshold, with a breakdown ---
if [ "$SCORE" -lt "$THRESHOLD" ]; then
  echo "::error ::README score ${SCORE}/7 is below threshold ${THRESHOLD}. Missing checks: ${FAILED:-none}."
  exit 1
fi
echo "::notice ::README score ${SCORE}/7 meets threshold ${THRESHOLD}."
