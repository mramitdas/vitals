# Vitals

**Purpose:** keep your README healthy — score it out of 7 and show a badge.

[![Vitals](badge.svg)](badge.svg)

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
      - uses: mramitdas/vitals/.github/actions/vitals@v1
        with:
          repo: ${{ github.repository }}
          threshold: 6
```

## How It Works

The action checks 7 criteria and returns a score from 0-7:

| Criteria | Check |
|---|---|
| Title/description present | First non-empty line is a heading or text (not a bare image) |
| Badges present | Contains at least one badge image outside code blocks |
| License mentioned | Contains license-related text |
| Code of Conduct mentioned | Contains CoC reference |
| Links present | At least one link, none empty |
| Contributing guidelines | Contains "contributing" or "contribute" |
| Purpose/description | First 5 lines contain purpose/description words |

Plus generates a **badge SVG** output:
```markdown
![Vitals: 7/7](badge.svg)
```

## Run Locally

```sh
INPUT_REPO= INPUT_THRESHOLD=6 GITHUB_WORKSPACE=. GITHUB_OUTPUT=/tmp/out \
  bash .github/actions/vitals/entrypoint.sh
cat /tmp/out
```

## Score Examples

| README Quality | Score |
|---|---|
| Minimal (title only) | 1/7 |
| Basic (title + badges) | 3/7 |
| Standard (good practices) | 6/7 |
| Excellent (full score) | 7/7 |

## Criteria Detail

1. **Title/description**: First non-empty line is a heading or text, not a bare image or link
2. **Badges**: Contains any `![alt](url)` image outside code blocks (URLs may contain parentheses, so shields.io works)
3. **License**: Contains `license`, or the whole word `mit`, `apache`, or `gpl` (case-insensitive)
4. **Code of Conduct**: Contains `code of conduct` or the whole word `conduct` (case-insensitive)
5. **Links**: Contains at least one link and no empty link URLs
6. **Contributing**: Contains `contributing` or `contribute` (case-insensitive)
7. **Purpose/description**: First 5 lines contain `purpose`, `description`, or `overview` (case-insensitive)

## Output

The action outputs two values:

- `score`: Numerical score from 0-7
- `badge_svg`: Raw SVG badge markup

Example outputs written to `$GITHUB_OUTPUT`:
```
score=7
badge_svg=<svg ...>vitals</text><text ...>7/7</text></svg>
```

To check another repo, set `repo: owner/repo`; leave it blank to check the current repo. Cross-repo checks clone over HTTPS, so private repos need a token/checkout step.

The badge in this README is generated from the script: run `bash scripts/update-badge.sh` to refresh `badge.svg`.

## License

MIT.