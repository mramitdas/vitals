#!/usr/bin/env bash
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ENTRY="$HERE/../.github/actions/vitals/entrypoint.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
PASS=0
FAIL=0

perfect_readme() {
  cat <<'EOF'
# Awesome Tool
Description of purpose.
![build](https://example.com/badge.svg)
## License
MIT
## Code of Conduct
Be nice.
## Contributing
PRs welcome.
EOF
}

run_case() {
  local name="$1" dir="$2" threshold="$3" want_score="$4" want_exit="$5"
  local repo="${6:-}" gh_repo="${7:-}"
  local out="$TMP/out"
  : > "$out"
  INPUT_REPO="$repo" INPUT_THRESHOLD="$threshold" GITHUB_WORKSPACE="$dir" \
    GITHUB_REPOSITORY="$gh_repo" GITHUB_OUTPUT="$out" bash "$ENTRY" >/dev/null 2>&1
  local rc=$?
  local got
  got="$(grep -E '^score=' "$out" | tail -1 | cut -d= -f2)"
  if [ "$got" = "$want_score" ] && [ "$rc" = "$want_exit" ]; then
    PASS=$((PASS + 1))
    printf 'PASS %s\n' "$name"
  else
    FAIL=$((FAIL + 1))
    printf 'FAIL %s (score=%s rc=%s, want score=%s rc=%s)\n' \
      "$name" "${got:-<none>}" "$rc" "$want_score" "$want_exit"
  fi
}

dir_perfect="$TMP/perfect"
mkdir -p "$dir_perfect"
perfect_readme > "$dir_perfect/README.md"
run_case "perfect readme scores 7/7" "$dir_perfect" 6 7 0

dir_tasklist="$TMP/tasklist"
mkdir -p "$dir_tasklist"
{ perfect_readme; echo '- [ ] todo'; } > "$dir_tasklist/README.md"
run_case "markdown task list keeps the link point" "$dir_tasklist" 6 7 0

dir_emptylink="$TMP/emptylink"
mkdir -p "$dir_emptylink"
{ perfect_readme; echo 'See [x]() here.'; } > "$dir_emptylink/README.md"
run_case "real empty link loses a point" "$dir_emptylink" 6 6 0

run_case "below threshold fails the job" "$dir_emptylink" 7 6 1

dir_variant="$TMP/variant"
mkdir -p "$dir_variant"
perfect_readme > "$dir_variant/Readme.md"
run_case "capitalized Readme.md is found" "$dir_variant" 6 7 0

run_case "matching repo uses workspace (no clone)" "$dir_perfect" 6 7 0 "owner/repo" "owner/repo"
run_case "invalid repo input fails" "$dir_perfect" 6 "" 1 "not a repo" ""

: > "$TMP/badge-out"
INPUT_REPO= INPUT_THRESHOLD=6 GITHUB_WORKSPACE="$dir_perfect" GITHUB_REPOSITORY= \
  GITHUB_OUTPUT="$TMP/badge-out" bash "$ENTRY" >/dev/null 2>&1
if grep -q 'vitals 7/7' "$TMP/badge-out" && grep -q '#4c1' "$TMP/badge-out"; then
  PASS=$((PASS + 1))
  printf 'PASS badge shows vitals 7/7 in green\n'
else
  FAIL=$((FAIL + 1))
  printf 'FAIL badge branding/color\n'
fi

echo "---"
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
