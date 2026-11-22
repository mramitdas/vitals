# Vitals

**Purpose:** keep your README healthy — score it out of 7 and show a badge.

[![Vitals](badge.svg)](#how-it-works)

A GitHub Action that checks any README and returns a score from 0-7 across 7 criteria, plus a machine-readable badge.

## Quick Start

### Install via GitHub Action

```yaml
# .github/workflows/vitals.yml
name: Vitals
on: [push, pull_request]
jobs:
  validate:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - uses: actions/checkout@v5
      - uses: mramitdas/vitals@v1
        with:
          repo: ${{ github.repository }}
          threshold: 6
```

## How It Works

The action checks 7 criteria and returns a score from 0-7:

| Criteria | Check |
|---|---|
| Title/description present | First meaningful line is a heading or text (not a bare image) |
| Badges present | Contains at least one badge-like image outside code blocks |
| License mentioned | A License heading, license name, or LICENSE file |
| Code of Conduct mentioned | Contains CoC reference (or a CODE_OF_CONDUCT file) |
| Links present | At least one link, none empty |
| Contributing guidelines | Contains "contributing" or "contribute" |
| Purpose/description | Purpose keyword or a prose sentence near the top |

Plus generates a **badge SVG** output:
```markdown
![Vitals: 7/7](badge.svg)
```

## Run Locally

```sh
INPUT_REPO= INPUT_THRESHOLD=6 GITHUB_WORKSPACE=. GITHUB_OUTPUT=/tmp/out \
  bash ./entrypoint.sh
cat /tmp/out
```

## Score Examples

| README Quality | Score |
|---|---|
| Minimal (title only) | 1/7 |
| Basic (title + badges) | 2/7 |
| Standard (good practices) | 6/7 |
| Excellent (full score) | 7/7 |

## Criteria Detail

1. **Title/description**: First meaningful line is a heading or text, not a bare image (an HTML-wrapped badge passes if the next line is a heading)
2. **Badges**: A badge-like image (`.svg`, `badge`, `shields`, `coverage`, workflow, etc.) outside code blocks; screenshots and prose images do not count
3. **License**: A `License` heading, a whole-word license name (`MIT`, `Apache`, `GPL`), or a `LICENSE`/`COPYING` file
4. **Code of Conduct**: Contains `code of conduct` or the whole word `conduct`, ignoring negations; or a `CODE_OF_CONDUCT` file
5. **Links**: At least one markdown, reference, or autolink, with none empty (whitespace-only or `#`)
6. **Contributing**: Contains `contributing` or `contribute`, ignoring negations
7. **Purpose/description**: A `purpose`/`description`/`overview` keyword in the first 10 lines, or a prose sentence of four or more words

## Output

The action outputs two values:

- `score`: Numerical score from 0-7
- `badge_svg`: Raw SVG badge markup

Example outputs written to `$GITHUB_OUTPUT`:
```
score=7
badge_svg<<VITALS_EOF
<svg ...>vitals</text><text ...>7/7</text></svg>
VITALS_EOF
```

To check another repo, set `repo: owner/repo`; leave it blank to check the current repo. Cross-repo checks clone over HTTPS; for a private repo pass `token: ${{ secrets.GITHUB_TOKEN }}`.

The badge in this README is generated from the script: run `bash scripts/update-badge.sh` to refresh `badge.svg`.

### Keep the badge fresh

To write the generated badge back on each push, run the action in a job with `contents: write`:

```yaml
    permissions:
      contents: write
    steps:
      - uses: actions/checkout@v5
      - id: vitals
        uses: mramitdas/vitals@v1
      - run: printf '%s' "${{ steps.vitals.outputs.badge_svg }}" > badge.svg
      - run: git commit -am 'chore: update badge' && git push || true
```

## License

MIT.