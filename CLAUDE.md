# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with this repository.

## Project Overview

Watchdoo is a standalone Apple Watch app that displays and manages the Cookidoo (Thermomix/Vorwerk) shopping list. It consists of three parts:

1. **Backend** (`backend/`) – Python FastAPI server wrapping the unofficial [cookidoo-api](https://github.com/miaucl/cookidoo-api) library
2. **Watch App** (Xcode target `Watchdoo Watch App`) – SwiftUI standalone watchOS 10+ app
3. **iPhone Companion App** (Xcode target `Watchdoo`) – iOS app used only for one-time configuration

Architecture: `Apple Watch ↔ Self-hosted FastAPI Backend ↔ Cookidoo Server`

Each user deploys their own backend instance. Cookidoo credentials never leave the user's server.

## Repository Layout

```
watchdoo/
├── backend/                              # FastAPI Python backend
│   ├── app/                              # Source
│   ├── tests/                            # pytest suite
│   ├── deploy/deploy.sh                  # Azure Container Apps deploy
│   └── Dockerfile
└── Watchdoo/Watchdoo/        # Xcode workspace
    ├── Watchdoo.xcodeproj
    ├── Watchdoo Watch App/         # watchOS target
    ├── Watchdoo/                   # iOS companion target
    ├── Watchdoo Watch AppTests/    # Watch unit tests
    └── WatchdooUITests/            # UI tests
```

The Xcode project uses `PBXFileSystemSynchronizedRootGroup` (Xcode 16+), so files added on disk are auto-detected — no manual `.pbxproj` edits required for source files.

## Backend

### Tech Stack
- Python 3.12+, FastAPI, aiohttp, cookidoo-api, Pydantic
- Hosted on Azure Container Apps (scale-to-zero)

### Commands
```bash
cd backend
source .venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Run locally
uvicorn app.main:app --reload

# Run tests
pytest tests/ -v

# Build Docker image
docker build -t watchdoo-backend .
```

### Configuration
All config via environment variables (see `.env.example`):
- `COOKIDOO_EMAIL`, `COOKIDOO_PASSWORD` – Cookidoo account credentials
- `COOKIDOO_COUNTRY`, `COOKIDOO_LANGUAGE` – Localization (e.g., `de`, `de-DE`)
- `API_KEY` – Shared secret between Watch app and backend
- `LOG_LEVEL` – Logging verbosity (default: `INFO`)

### Architecture Notes
- `app/services/cookidoo.py` – Singleton service wrapping cookidoo-api with auto-retry on auth failures
- `app/middleware.py` – API key verification via `X-API-Key` header
- `app/routers/shopping_list.py` – All shopping list CRUD endpoints
- Health endpoint (`/api/v1/health`) requires no authentication

### Important: Ownership Cross-Reference
The cookidoo-api library returns ingredient ownership status (`is_owned`) only on the **flat ingredient list**, while the **recipe-grouped ingredients** carry the recipe association. Recipe ingredients always have `is_owned=False` from the library directly.

`shopping_list.py` builds a `(name, description) → is_owned` lookup dict from the flat list and then injects the correct `is_owned` value into recipe ingredients before returning them. Without this, the "Gerichte" view on the Watch would never show checked items.

### Known Limitations
- **Shopping categories** (`shoppingCategory_ref`) are not exposed by `cookidoo-api`. The Watch app currently shows a flat sorted list (unchecked first, then checked) instead of grouping by category.

### Testing
Tests use `pytest` + `anyio` with `httpx.AsyncClient` for endpoint testing. The Cookidoo service is mocked in all tests – no real API calls are made. Run with `pytest tests/ -v`.

## Watch App

### Tech Stack
- SwiftUI, watchOS 10+, standalone
- URLSession async/await for networking
- `WatchConnectivity` for receiving config from companion app

### Structure
```
Watchdoo Watch App/
├── WatchdooApp.swift        # @main + ContentView + SetupPromptView
├── Models/
│   ├── ShoppingModels.swift       # Codable types + ShoppingItem enum
│   └── ShoppingListViewModel.swift # @MainActor ObservableObject
├── Views/
│   ├── ShoppingListView.swift     # Main list (toolbar toggle Zutaten/Gerichte)
│   ├── ItemRowView.swift
│   └── AddItemView.swift
├── Services/APIService.swift      # actor + URLSession
├── Connectivity/WatchConnectivityManager.swift
└── Localizable.xcstrings          # i18n catalog (de source, en translation)
```

### Navigation
- **Toolbar toggle** (top-right): icon switches between "Zutaten" (flat list) and "Gerichte" (grouped by recipe). Title bar reflects current mode.
- **Plus button** centered in bottom toolbar opens AddItemView.
- **Swipe-to-delete** with `allowsFullSwipe: false` (forces tap on Delete button) to avoid accidental deletes.
- Deleting a recipe ingredient shows a confirmation dialog ("removes the entire recipe").

⚠️ **Do not use `TabView(.page)` for the Zutaten/Gerichte toggle** – it eats the swipe gesture and breaks `swipeActions` on list rows. Toolbar toggle is the only conflict-free pattern we found that fits.

### State Management
- `@AppStorage("serverURL")` and `@AppStorage("apiKey")` – persisted config
- Reactive: when `WatchConnectivityManager.receivedConfig` flips to true, list auto-fetches
- Optimistic updates: UI updates immediately on toggle, reverts on API failure
- `displayName` for ingredients: `"\(description) \(name)"` (e.g. "200 g Wasser")

### Configuration Flow
The Watch app has **no input fields**. Configuration goes:
1. User runs companion app on iPhone
2. Enters server URL + API key (or pastes deploy script output)
3. Taps "An Watch senden" → `WCSession.transferUserInfo`
4. Watch's `WatchConnectivityManager` receives, writes to `UserDefaults`, sets `receivedConfig = true`
5. ContentView re-renders, ShoppingListView fetches data

If the user wants to reconfigure, they re-send from the iPhone (which overwrites the values).

### Testing
XCTest-based tests in `Watchdoo Watch AppTests/`. Run via Xcode (⌘+U). Tests cover model decoding, ViewModel grouping logic, and API error types.

## iPhone Companion App

Located in the Xcode target `Watchdoo` (the iOS one). The companion is **only used for setup** — after sending config, the Watch app runs fully standalone.

Key files:
- `Watchdoo/WatchdooCompanionApp.swift` – @main entry
- `Watchdoo/Views/SetupView.swift` – form: server URL, API key, paste-from-clipboard, test connection, send to Watch
- `Watchdoo/Services/PhoneConnectivityManager.swift` – iOS-side WCSession delegate

The companion uses `transferUserInfo` (queued, guaranteed delivery) plus `updateApplicationContext` (latest-state) for robustness even if the Watch is offline at send time.

## i18n / Localization

Both targets ship with a **String Catalog** (`Localizable.xcstrings`):
- **Source language: German** (`sourceLanguage = "de"` in catalog, `developmentRegion = de` in project)
- **Translations**: English
- Strings appear as German keys; English locale users get the `en.lproj` translations
- Other locales fall back to German source

When adding new user-facing strings:
- Use `Text("Foo")` literals — Xcode auto-extracts to the catalog on next build
- For non-`Text` contexts (returning a `String` from a function, error descriptions), use `String(localized: "Foo")`
- For SwiftUI APIs accepting both, prefer `LocalizedStringKey` typing on stored properties

Open the `.xcstrings` file in Xcode to edit translations in a table UI or add new languages.

## API Endpoints

All endpoints (except health) require `X-API-Key` header.

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/api/v1/health` | Health check (no auth) |
| GET | `/api/v1/shopping-list` | Full shopping list |
| PATCH | `/api/v1/shopping-list/ingredients` | Toggle ingredient ownership |
| PATCH | `/api/v1/shopping-list/additional-items/ownership` | Toggle additional item ownership |
| POST | `/api/v1/shopping-list/additional-items` | Add custom items |
| PUT | `/api/v1/shopping-list/additional-items` | Edit custom items |
| DELETE | `/api/v1/shopping-list/additional-items/{id}` | Remove custom item |
| DELETE | `/api/v1/shopping-list/recipes/{recipe_id}` | Remove recipe ingredients |
| POST | `/api/v1/auth/refresh` | Force token refresh |

## Development Tips

### Setting UserDefaults on the simulator
```bash
xcrun simctl spawn <UDID> defaults write com.example.Watchdoo.watchkitapp serverURL -string "http://host.docker.internal:8000"
xcrun simctl spawn <UDID> defaults write com.example.Watchdoo.watchkitapp apiKey -string "<api-key>"
```

### Build commands (CLI)
```bash
cd Watchdoo/Watchdoo

# Watch app
xcodebuild -project Watchdoo.xcodeproj -scheme "Watchdoo Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build

# Companion app
xcodebuild -project Watchdoo.xcodeproj -scheme "Watchdoo" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

### Test app in different language
- Per-scheme: Xcode → Edit Scheme → Run → Options → "App Language" → English → ⌘+R
- System-wide: Settings.app in simulator → General → Language & Region

## Important Caveats

- This project uses an **unofficial API**. It may break when Cookidoo updates their backend.
- The cookidoo-api library requires **Python 3.12+**.
- The Dockerfile uses `python:3.12-slim` to ensure compatibility.
- Swift 6 / Xcode 16: `import Combine` is no longer implicit — must be imported explicitly for `@Published`/`ObservableObject`.
- watchOS 10+ does not support `.pickerStyle(.segmented)` — use `.navigationLink` style or another control.
- watchOS 10+ does not support `.indexViewStyle(.page(backgroundDisplayMode: .always))` — only the default style.
- `contextMenu` on watchOS list rows is unreliable since Force-Touch removal — prefer `swipeActions`.
