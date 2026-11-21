# README Validator End-to-End Fixes — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the README Validator action actually run, score correctly on a real 7-point scale, fail a build when below threshold, and stop shipping broken install instructions or leftover docs from another project.

**Architecture:** One composite GitHub Action (`action.yml` + `entrypoint.sh`) plus one small hand-written shell test harness. The script reads a README from the checked-out workspace (or clones another repo when asked), applies seven checks each worth one point, writes `score` and `badge_svg` to `$GITHUB_OUTPUT`, and exits non-zero when the score is below `threshold`. Docs are corrected to match.

**Tech Stack:** POSIX shell / bash, GitHub Actions composite action, `gh` for issue tracking. No runtime dependencies.

**Spec:** The 16-finding ponytail audit in this conversation (findings referenced by number below). Constraints copied from it: no new dependencies, prefer deletion, keep the seven checks, one tiny test that fails when a check breaks.

## Global Constraints

- Maximum score is **7** (seven checks, one point each). Everywhere it says `/10` becomes `/7` (`entrypoint.sh`, `action.yml` output description, `badge.svg`, `README.md`).
- Default threshold **6**; below-threshold run must `exit 1`.
- Portability: no `grep -P`, no non-greedy `.*?` in ERE. Must run on both Ubuntu CI and macOS.
- No binary install path: this repo ships an action, not a `bugsnap` binary and not Go code.
- Do not add dependencies. Test harness is plain bash.

## Review Focus

- A README that uses Markdown task lists (`- [ ] todo`) must NOT lose the "no empty links" point; a README containing a real empty link `[]()` must lose it.
- A perfect seven-check README must score exactly 7 and pass default threshold.
- Running on a PR must score the checked-out commit, not the default branch.
- A lowercase/capitalized variant filename (`Readme.md`) must still be found.
- A below-threshold score must turn the job red, not just print a warning.

---

### Task 1: Make the action runnable (composite action)

**Files:**
- Modify: `.github/actions/readme-validator/action.yml`

**Interfaces:**
- Produces: action with step id `validator`, inputs `repo`/`threshold`, outputs `score`/`badge_svg`.

- [ ] **Step 1: Replace the runs block and inputs wiring**

Change `runs:` to a composite that injects inputs as `INPUT_*` env vars and runs the script through the action's own path:

```yaml
runs:
  using: 'composite'
  steps:
    - id: validator
      shell: bash
      env:
        INPUT_REPO: ${{ inputs.repo }}
        INPUT_THRESHOLD: ${{ inputs.threshold }}
      run: bash "${{ github.action_path }}/entrypoint.sh"
```

Keep `outputs.score.value: ${{ steps.validator.outputs.score }}` and the badge output; they now resolve.

- [ ] **Step 2: Verify YAML parses and the wiring is present**

Run: `python3 -c "import yaml,sys;yaml.safe_load(open('.github/actions/readme-validator/action.yml'))" && grep -q "using: 'composite'" .github/actions/readme-validator/action.yml`
Expected: no error, exit 0.

- [ ] **Step 3: Commit**

```bash
git add .github/actions/readme-validator/action.yml
git commit -m "fix: make readme-validator a runnable composite action"
```

---

### Task 2: Point the workflow at the local action and check out the code

**Files:**
- Modify: `.github/workflows/README-validate.yml`
- Modify: `README.md` (Quick Start snippet, lines ~13-27)

**Interfaces:**
- Consumes: Task 1's action at `./.github/actions/readme-validator`.

- [ ] **Step 1: Edit the workflow**

Add a checkout step and use the local action:

```yaml
    steps:
      - uses: actions/checkout@v4
      - uses: ./.github/actions/readme-validator
        with:
          repo: ${{ github.repository }}
          threshold: 6
```

- [ ] **Step 2: Mirror the same snippet in README Quick Start.**

- [ ] **Step 3: Verify no dead action reference remains**

Run: `! grep -R "readme-val/readme-validator@v1" .github README.md`
Expected: exit 0 (the string is gone).

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/README-validate.yml README.md
git commit -m "fix: run the local validator action in CI"
```

---

### Task 3: Delete the broken installer and the fake Go install

**Files:**
- Delete: `scripts/install.sh` (untracked; `rm`)
- Modify: `README.md` (remove `curl | sh`, `go install`, and the two "Try It"/install blocks)

**Interfaces:**
- Produces: README install section that only shows the action, plus a "run locally" line using `entrypoint.sh`.

- [ ] **Step 1: Remove the script**

Run: `rm scripts/install.sh`

- [ ] **Step 2: In README, delete every `curl -fsSL ... install.sh | sh` line and every `go install github.com/mramitdas/readme-val` line.**

- [ ] **Step 3: Replace install guidance with the action snippet and one local-run line: `INPUT_REPO= INPUT_THRESHOLD=6 GITHUB_WORKSPACE=. GITHUB_OUTPUT=/tmp/out bash .github/actions/readme-validator/entrypoint.sh`.**

- [ ] **Step 4: Verify the dead references are gone**

Run: `! grep -nE "install\.sh|go install|bugsnap" README.md`
Expected: exit 0.

- [ ] **Step 5: Commit**

```bash
git add -A README.md scripts
git commit -m "fix: remove broken installer; document the action only"
```

---

### Task 4: Score on a 7-point scale and add the test harness

**Files:**
- Modify: `.github/actions/readme-validator/entrypoint.sh`
- Modify: `.github/actions/readme-validator/action.yml` (output description `/10` -> `/7`)
- Modify: `badge.svg`
- Create: `test/readme_validator_test.sh`

**Interfaces:**
- Produces: `entrypoint.sh` reads a local directory when no remote repo is requested (uses `GITHUB_WORKSPACE` or `PWD`), so it can be tested without cloning. Env consumed: `INPUT_REPO`, `INPUT_THRESHOLD`, `GITHUB_WORKSPACE`, `GITHUB_OUTPUT`, `GITHUB_REPOSITORY`.

- [ ] **Step 1: Write the harness with the perfect-README case**

`test/readme_validator_test.sh` creates a temp dir, writes the fixture below as `README.md`, runs the entrypoint with `INPUT_REPO=` empty, `GITHUB_WORKSPACE=<dir>`, `GITHUB_OUTPUT=<tmpfile>`, and asserts `score=7` and exit 0:

```markdown
# Awesome Tool
Description of purpose.
![build](https://example.com/badge.svg)
## License
MIT
## Code of Conduct
Be nice.
## Contributing
PRs welcome.
```

- [ ] **Step 2: Update entrypoint: remove `MAX_SCORE=10`; when `REPO` is empty use the local workspace directory instead of erroring; find the README there. Change badge aria-label/text to `${SCORE}/7`.**

- [ ] **Step 3: Run the harness**

Run: `bash test/readme_validator_test.sh`
Expected: PASS (score 7).

- [ ] **Step 4: Update `badge.svg` text to `Score: 7/7` and `action.yml` description to `(0-7)`.**

- [ ] **Step 5: Commit**

```bash
git add .github/actions/readme-validator test badge.svg
git commit -m "fix: score out of 7 and add scoring test harness"
```

---

### Task 5: Fix the empty-link check and make grep portable

**Files:**
- Modify: `.github/actions/readme-validator/entrypoint.sh`
- Modify: `test/readme_validator_test.sh`

- [ ] **Step 1: Add two failing cases to the harness**: a README identical to the perfect one but with an extra line `- [ ] todo` must still score 7; a README with `[x]()` must score 6.

- [ ] **Step 2: Run harness, confirm both new cases fail.**

- [ ] **Step 3: Replace the link check with a `[]()` match using `grep -E` (no `-P`); replace the badge regex `.*?` with `!\[[^]]*\]\([^)]*\.(svg|png|gif)` under `-E`.**

- [ ] **Step 4: Run harness**

Expected: all cases pass.

- [ ] **Step 5: Commit**

```bash
git add .github/actions/readme-validator/entrypoint.sh test/readme_validator_test.sh
git commit -m "fix: detect real empty links; drop non-portable grep"
```

---

### Task 6: Make threshold fail the build

**Files:**
- Modify: `.github/actions/readme-validator/entrypoint.sh`
- Modify: `test/readme_validator_test.sh`
- Modify: `SHARE_TEMPLATE.md` (only if it mentions pass/fail semantics)

- [ ] **Step 1: Add a harness case**: score 6 with `INPUT_THRESHOLD=7` must exit 1 and still write `score=6`; score 7 with threshold 6 exits 0.

- [ ] **Step 2: Run harness, confirm the failing case fails.**

- [ ] **Step 3: Replace the `::warning` block with: print `::error` then `exit 1` when `SCORE < THRESHOLD`; add a one-line `::notice` when passing.**

- [ ] **Step 4: Run harness**

Expected: all pass, including exit codes.

- [ ] **Step 5: Commit**

```bash
git add .github/actions/readme-validator/entrypoint.sh test/readme_validator_test.sh
git commit -m "fix: fail the job when score is below threshold"
```

---

### Task 7: Score the checked-out commit, harden the clone, validate the repo input, find README variants

**Files:**
- Modify: `.github/actions/readme-validator/entrypoint.sh`
- Modify: `test/readme_validator_test.sh`

**Interfaces:**
- Consumes: Task 4's local-directory resolution.
- Produces: source selection rule — if `REPO` is empty OR equals `GITHUB_REPOSITORY`, read `GITHUB_WORKSPACE`/`PWD`; otherwise clone `REPO` (`--depth 1`, no stderr suppression) after validating `^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$`. README lookup is case-insensitive (`readme*`).

- [ ] **Step 1: Add harness cases**: a dir containing `Readme.md` scores correctly; a bad `INPUT_REPO="not a repo"` exits 1 with an input error (no clone attempt).

- [ ] **Step 2: Run harness, confirm the new cases fail.**

- [ ] **Step 3: Implement source selection, repo validation (`^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$`), `find "$dir" -maxdepth 1 -type f -iname 'readme*' | head -1`, `git clone --depth 1` without `2>/dev/null`, and a cleanup `trap`.**

- [ ] **Step 4: Run harness**

Expected: all cases pass.

- [ ] **Step 5: Commit**

```bash
git add .github/actions/readme-validator/entrypoint.sh test/readme_validator_test.sh
git commit -m "fix: validate checked-out commit; harden clone and input handling"
```

---

### Task 8: Clean up README leftovers

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Delete** the bugsnap `result.json` block (`video`/`poster`/`durationSeconds`), the "Demo" section, and the second duplicate "Try It" section. Replace the Output section with the real outputs `score` (0-7) and `badge_svg`.

- [ ] **Step 2: Fix the score-examples table** to the 7-point scale (match the seven checks).

- [ ] **Step 3: Verify leftovers are gone**

Run: `! grep -niE "bugsnap|cursorcam|video|poster|durationSeconds" README.md && [ "$(grep -c '^## Try It' README.md)" -eq 1 ]`
Expected: exit 0.

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "docs: remove leftover content from another project"
```

---

### Task 9: Clean up SHARE_TEMPLATE

**Files:**
- Modify: `SHARE_TEMPLATE.md`

- [ ] **Step 1: Remove the false "GitHub Actions will post the score as a comment" claim and the stub scoring snippet; point to the real workflow. Renumber the duplicated `## 2.` sections.**

- [ ] **Step 2: Verify**

Run: `! grep -niE "post the score as a comment|scoring logic from" SHARE_TEMPLATE.md && [ "$(grep -c '^## ' SHARE_TEMPLATE.md)" -ge 1 ]`
Expected: exit 0.

- [ ] **Step 3: Commit**

```bash
git add SHARE_TEMPLATE.md
git commit -m "docs: remove false comment claim; fix section numbering"
```

---

### Task 10: End-to-end verification and close issues

**Files:** none (verification only)

- [ ] **Step 1: Run the full harness**

Run: `bash test/readme_validator_test.sh`
Expected: all cases PASS.

- [ ] **Step 2: Run this repo's own validator on itself**

Run: `INPUT_REPO= INPUT_THRESHOLD=6 GITHUB_WORKSPACE=. GITHUB_OUTPUT=/tmp/self-score bash .github/actions/readme-validator/entrypoint.sh; cat /tmp/self-score`
Expected: `score>=6`, exit 0.

- [ ] **Step 3: Static check YAML**

Run: `python3 -c "import yaml;yaml.safe_load(open('.github/actions/readme-validator/action.yml'));yaml.safe_load(open('.github/workflows/README-validate.yml'))"`
Expected: no error.

- [ ] **Step 4: Close each GitHub issue** with `gh issue close <n> --comment "Fixed in <commit>; tests: bash test/readme_validator_test.sh"` as its task lands.

---

## Finding-to-task map (for GitHub issues)

| Issue | Task | Findings |
|---|---|---|
| Action cannot run | 1 | 1 |
| Workflow dead action ref | 2 | 2 |
| Broken installer / fake Go install | 3 | 3, 4 |
| Score never reaches 10 | 4, 5 | 5, 14 |
| Empty-link check wrong | 5 | 6 |
| Threshold never fails | 6 | 7 |
| Scores default branch not commit; clone/input/filename | 7 | 8, 10, 13, 16 |
| Unused MAX_SCORE | 4 | 14 |
| Non-portable grep | 5 | 15 |
| README leftovers | 8 | 11 |
| SHARE_TEMPLATE false claims | 9 | 12 |
| Missing tests | 4-7 | 9 |
