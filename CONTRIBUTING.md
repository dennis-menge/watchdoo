# Contributing to Watchdoo

Thanks for your interest in contributing! This is a small hobby project, but PRs and issues are welcome.

## Before You Start

- Open an issue first for non-trivial changes so we can discuss the approach
- Keep PRs focused — one feature or fix per PR
- This project relies on the unofficial [`cookidoo-api`](https://github.com/miaucl/cookidoo-api). API-related issues there should be reported upstream.

## Project Structure

See the [README](README.md#projektstruktur) for the layout. In short:

- `backend/` — FastAPI app wrapping `cookidoo-api`
- `Watchdoo/` — Xcode project containing the watchOS app and iOS companion app

## Backend (Python)

```bash
cd backend
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env  # then fill in your credentials

# Run locally
uvicorn app.main:app --reload

# Run tests
pytest
```

### Style

- Follow existing patterns in `app/` — Pydantic models in `models.py`, route handlers thin and delegating to `services/cookidoo.py`
- Add a test in `backend/tests/` for any new endpoint or behavior change
- No formatter is enforced; please match surrounding style

## Before your first commit: install git hooks

The repo ships a pre-commit hook that strips your personal Apple
Developer Team ID out of `*.pbxproj` files automatically — Xcode's
"Automatically manage signing" likes to rewrite `DEVELOPMENT_TEAM = ""`
back to your team every time you open the project, and that team ID
must not end up in upstream commits.

One-time setup after cloning:

```bash
./scripts/install-hooks.sh
```

That command sets `git config core.hooksPath .githooks`, after which
every commit that touches a `*.pbxproj` runs through `.githooks/pre-commit`.
The hook detects 10-character uppercase team IDs (e.g. `5J8KP44BWJ`) and
replaces them with `DEVELOPMENT_TEAM = ""` in-place, then re-stages the
file. You'll see a one-line `pre-commit: stripping personal
DEVELOPMENT_TEAM from …` notice when it kicks in.

Your local Xcode setup is unaffected — the team only matters in the
working tree at build time, not in committed history.

## Watch / Companion App (Swift)

- Open `Watchdoo/Watchdoo/Watchdoo.xcodeproj` in Xcode 15+
- Replace the placeholder bundle identifiers (`com.example.Watchdoo*`) with your own and select your Apple Developer Team
- Both targets share `Models/` and `Services/` via the project, but UI code is target-specific (`Views/` in each target)
- Strings live in `Localizable.xcstrings` (German source, English translations)

### When adding strings

1. Use SwiftUI's `Text("…")` or `String(localized: "…")` directly — Xcode will auto-extract
2. Open `Localizable.xcstrings` and add the English translation
3. Don't hard-code language-specific text in code

## Commit Messages

- Use the imperative mood: "Add X", "Fix Y", "Refactor Z"
- Reference issues with `#NNN` if applicable
- Keep the subject line ≤ 72 characters; explain *why* in the body when not obvious

## Code of Conduct

Be kind. Assume good faith.

## Dependency hygiene

Watchdoo automates routine dependency maintenance:

- **Dependabot** (`.github/dependabot.yml`) opens weekly PRs for
  - Python deps in `backend/requirements.txt` (grouped minor + patch)
  - Docker base image in `backend/Dockerfile`
  - GitHub Actions versions used in workflows
- **CodeQL** (`.github/workflows/codeql.yml`) scans Python and Swift on
  every push/PR plus a weekly cron, with the `security-and-quality`
  query suite. Findings show up under the repo's *Security → Code scanning*.
- **Trivy** scans the built backend container image on every backend CI
  run and uploads SARIF results to *Security → Code scanning* under
  category `trivy-image`. Only fixable HIGH/CRITICAL findings are
  reported to keep the noise down.
- **Scheduled rebuild**: the backend workflow runs Mondays 04:00 UTC
  even without code changes so base-image security patches flow through
  without manual action.

If you intentionally need to pin a vulnerable version (e.g. waiting for
an upstream fix), document the reason in the PR/commit and revisit when
a patched release ships.

The Watch and iOS apps currently have **no third-party Swift packages**;
their only "dependency" is the Apple SDK / Xcode toolchain, which is
managed by upgrading Xcode locally and updating the deployment targets
in `Watchdoo.xcodeproj` deliberately.
