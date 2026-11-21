# README Validator

**Validate README quality and generate a health score badge.**

[![README Score](badge.svg)](badge.svg)

A GitHub Action that checks any README and returns a score from 0-10 across 7 criteria, plus a machine-readable badge.

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

### Install via cURL

```sh
curl -fsSL https://raw.githubusercontent.com/mramitdas/readme-val/main/scripts/install.sh | sh
```

### Or via Go

```sh
go install github.com/mramitdas/readme-val@v0.1.0
```

## How It Works

The action checks 7 criteria and returns a score from 0-10:

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
![README Score: 7/10](badge.svg)
```

## Try It

```sh
# Option 1: One-line install
curl -fsSL https://raw.githubusercontent.com/mramitdas/readme-val/main/scripts/install.sh | sh

# Option 2: Go install
go install github.com/mramitdas/readme-val@v0.1.0

# Option 3: Manual clone
git clone https://github.com/mramitdas/readme-val
cd readme-val
```

## Score Examples

| README Quality | Score |
|---|---|
| Minimal (title only) | 1/10 |
| Basic (title + badges) | 3/10 |
| Standard (good practices) | 6/10 |
| Excellent (full score) | 10/10 |

## Criteria Detail

1. **Title/description**: First line is not empty after removing `# ` or `## `
2. **Badges**: Contains `!\[.*?\]\(.*?\.(svg|png|gif)` pattern
3. **License**: Contains `license`, `mit`, `apache`, or `gpl` (case-insensitive)
4. **Code of Conduct**: Contains `code of conduct` or `conduct` (case-insensitive)
5. **No empty links**: No `\[ \]` pattern in the README
6. **Contributing**: Contains `contributing` or `contribute` (case-insensitive)
7. **Purpose/description**: First 5 lines contain `purpose`, `description`, or `overview` (case-insensitive)

## Output

The action outputs two values:

- `score`: Numerical score from 0-10
- `badge_svg`: Markdown-ready SVG badge code

Example `result.json`:
```json
{
  "ok": true,
  "exitCode": 0,
  "video": "/tmp/cursorcam-run/bugsnap-demo-20261120-193852-e84f/video-x.mp4",
  "poster": "/tmp/cursorcam-run/bugsnap-demo-20261120-193852-e84f/poster-x.jpg",
  "sizeBytes": 1038094,
  "durationSeconds": 7.733333333333333,
  "warnings": []
}
```

## Try It

```sh
# Option 1: One-line install
curl -fsSL https://raw.githubusercontent.com/mramitdas/readme-val/main/scripts/install.sh | sh

# Option 2: Go install
go install github.com/mramitdas/readme-val@v0.1.0

# Option 3: Manual clone
git clone https://github.com/mramitdas/readme-val
cd readme-val
```

## Demo

A CursorCam-generated demo video is available at `site/demo/bugsnap-demo.mp4` (7.7s, 1.0MB, 1920×1080 30fps).

The demo checks a simulated terminal session showing the capture, inspect, and replay workflow of bugsnap.

## License

MIT. Not affiliated with SmartBear BugSnag.