# README Validator

**Validate README quality and generate a health score badge.**

[![README Score](badge.svg)](badge.svg)

A GitHub Action that checks any README and returns a score from 0-7 across 7 criteria, plus a machine-readable badge.

## Quick Start

### Install via GitHub Action

```yaml
# .github/workflows/README-validate.yml
name: README Validator
on: [push, pull_request]
jobs:
  validate:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - uses: actions/checkout@v4
      - uses: ./.github/actions/readme-validator
        with:
          repo: ${{ github.repository }}
          threshold: 6
```

## How It Works

The action checks 7 criteria and returns a score from 0-7:

| Criteria | Check |
|---|---|
| Title/description present | First line is not empty |
| Badges present | Contains at least one badge image |
| License mentioned | Contains license-related text |
| Code of Conduct mentioned | Contains CoC reference |
| No empty links | No bare `[]()` link syntax |
| Contributing guidelines | Contains "contributing" or "contribute" |
| Purpose/description | First 5 lines contain purpose/description words |

Plus generates a **Markdown badge SVG** output:
```markdown
![README Score: 7/7](badge.svg)
```

## Run Locally

```sh
INPUT_REPO= INPUT_THRESHOLD=6 GITHUB_WORKSPACE=. GITHUB_OUTPUT=/tmp/out \
  bash .github/actions/readme-validator/entrypoint.sh
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

1. **Title/description**: First line is not empty after removing `# ` or `## `
2. **Badges**: Contains `!\[[^]]*\]\([^)]*\.(svg|png|gif)` pattern
3. **License**: Contains `license`, `mit`, `apache`, or `gpl` (case-insensitive)
4. **Code of Conduct**: Contains `code of conduct` or `conduct` (case-insensitive)
5. **No empty links**: No `[]()` pattern in the README
6. **Contributing**: Contains `contributing` or `contribute` (case-insensitive)
7. **Purpose/description**: First 5 lines contain `purpose`, `description`, or `overview` (case-insensitive)

## Output

The action outputs two values:

- `score`: Numerical score from 0-7
- `badge_svg`: Markdown-ready SVG badge code

Example outputs written to `$GITHUB_OUTPUT`:
```
score=7
badge_svg=<svg ...>Score: 7/7</svg>
```

## License

MIT.