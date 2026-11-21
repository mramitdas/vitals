#!/usr/bin/env bash
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ENTRY="$HERE/../.github/actions/readme-validator/entrypoint.sh"
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
  local out="$TMP/out"
  : > "$out"
  INPUT_REPO= INPUT_THRESHOLD="$threshold" GITHUB_WORKSPACE="$dir" \
    GITHUB_REPOSITORY= GITHUB_OUTPUT="$out" bash "$ENTRY" >/dev/null 2>&1
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

echo "---"
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
