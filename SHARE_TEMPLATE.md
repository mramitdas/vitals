# Share Your Vitals Score

Ready to check your repo's README health? Here's how:

## 1. Add the Action

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
      - uses: mramitdas/vitals/.github/actions/vitals@main
        with:
          repo: ${{ github.repository }}
          threshold: 6
```

To check another repo, set `repo: owner/repo`. The action writes `score` (0-7) and `badge_svg` to its outputs, and fails the job when the score is below `threshold`.

## 2. Share Your Score

Post this on social media:

```
My README scored 7/7 on @readme_val health check 📊

What did yours score? 👇

#ReadmeValidation #DevTools #SoftwareQuality
```

## 3. Sample Post Texts

**Twitter/LinkedIn:**
"🚀 Just validated my README with the new @readme_val GitHub Action and scored 7/7! The action checks title, badges, license, contributing guidelines & more. #DevTools #SoftwareQuality"

**Twitter (short):**
"My README scored 7/7 — can yours beat it? 📊 @readme_val #CodeQuality #SoftwareEngineering"

**Reddit (r/programming):**
"Built a GitHub Action that validates README quality and scores 0-7. curious to see everyone's scores! https://github.com/mramitdas/vitals"
