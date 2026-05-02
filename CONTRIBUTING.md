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
