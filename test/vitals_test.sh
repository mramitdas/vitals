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

dir_commit="$TMP/commit"
mkdir -p "$dir_commit"
printf '# Repo\nThis project has a commit history.\n' > "$dir_commit/README.md"
run_case "word 'commit' is not a license" "$dir_commit" 0 1 0

dir_conduct="$TMP/conduct"
mkdir -p "$dir_conduct"
printf '# Repo\nWe conducted tests.\n' > "$dir_conduct/README.md"
run_case "word 'conducted' is not a code of conduct" "$dir_conduct" 0 1 0

dir_empty="$TMP/empty"
mkdir -p "$dir_empty"
: > "$dir_empty/README.md"
run_case "empty readme scores 0" "$dir_empty" 0 0 0

dir_priority="$TMP/priority"
mkdir -p "$dir_priority"
perfect_readme > "$dir_priority/README.md"
printf '# Other\n' > "$dir_priority/readme-old.md"
run_case "README.md wins over other readme files" "$dir_priority" 0 7 0

dir_fenced="$TMP/fenced"
mkdir -p "$dir_fenced"
printf '# Docs\nDescription of purpose.\nSee [docs](https://example.com).\n```markdown\n![example](x)\n```\n## License\nMIT\n## Code of Conduct\nBe nice.\n## Contributing\nPRs welcome.\n' > "$dir_fenced/README.md"
run_case "image inside code fence is not a badge" "$dir_fenced" 0 6 0

dir_paren="$TMP/paren"
mkdir -p "$dir_paren"
perfect_readme | sed 's#https://example.com/badge.svg#https://en.wikipedia.org/wiki/Foo_(bar).svg#' > "$dir_paren/README.md"
run_case "badge URL with parentheses counts" "$dir_paren" 6 7 0

dir_shields="$TMP/shields"
mkdir -p "$dir_shields"
perfect_readme | sed 's#https://example.com/badge.svg#https://img.shields.io/badge/build-passing-green#' > "$dir_shields/README.md"
run_case "extensionless shields.io badge counts" "$dir_shields" 6 7 0

dir_badgeonly="$TMP/badgeonly"
mkdir -p "$dir_badgeonly"
printf '![badge](x.svg)\nDescription of purpose.\n## License\nMIT\n## Code of Conduct\nBe nice.\n## Contributing\nPRs welcome.\n' > "$dir_badgeonly/README.md"
run_case "badge-only first line gets no title point" "$dir_badgeonly" 0 6 0

run_case "non-numeric threshold fails" "$dir_perfect" "abc" "" 1
run_case "out-of-range threshold fails" "$dir_perfect" "9" "" 1
run_case "missing workspace directory fails" "$TMP/does-not-exist" 6 "" 1

: > "$TMP/badge-out"
INPUT_REPO= INPUT_THRESHOLD=6 GITHUB_WORKSPACE="$dir_perfect" GITHUB_REPOSITORY= \
  GITHUB_OUTPUT="$TMP/badge-out" bash "$ENTRY" >/dev/null 2>&1
if grep -q '>vitals<' "$TMP/badge-out" && grep -q '>7/7<' "$TMP/badge-out" && grep -q '#4c1' "$TMP/badge-out"; then
  PASS=$((PASS + 1))
  printf 'PASS scorecard shows vitals 7/7 in green\n'
else
  FAIL=$((FAIL + 1))
  printf 'FAIL scorecard branding/color\n'
fi

: > "$TMP/badge-low"
INPUT_REPO= INPUT_THRESHOLD=0 GITHUB_WORKSPACE="$dir_commit" GITHUB_REPOSITORY= \
  GITHUB_OUTPUT="$TMP/badge-low" bash "$ENTRY" >/dev/null 2>&1
if grep -q '>1/7<' "$TMP/badge-low" && grep -q '#e05d44' "$TMP/badge-low"; then
  PASS=$((PASS + 1))
  printf 'PASS low score turns the scorecard red\n'
else
  FAIL=$((FAIL + 1))
  printf 'FAIL low-score badge color\n'
fi

echo "---"
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
