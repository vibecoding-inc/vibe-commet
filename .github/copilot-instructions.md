# Copilot Instructions for Vibe-Commet (Commet)

## Project Overview

**Commet** is a cross-platform Matrix chat client built with Flutter/Dart. It supports Windows, Linux, Android, Web (and planned macOS/iOS). The repository is a monorepo containing four Dart/Flutter packages:

- **`commet/`** — Main application
- **`tiamat/`** — Custom Material Design system/component library used by the app
- **`widgets/calendar/`** — Reusable calendar widget
- **`widgets/matrix_widget_api/`** — Matrix widget protocol API

The project uses a Dart workspace (root `pubspec.yaml`) so packages share a single `pubspec.lock`.

---

## Environment Setup

### Required System Dependencies (Linux)

```bash
sudo apt-get update -y
sudo apt-get install -y ninja-build libgtk-3-dev libmpv-dev mpv ffmpeg libmimalloc-dev webkit2gtk-4.1 keybinder-3.0
```

### Flutter Version

The project uses **Flutter 3.41.1** (stable channel).

```bash
flutter config --enable-linux-desktop  # required for Linux desktop builds
```

### Java (Android builds only)

Java 17 is required for Android builds.

---

## Getting Started

Always run these steps before working on the code:

```bash
# 1. Install Dart/Flutter dependencies (run from repo root or commet/)
cd commet
flutter pub get

# 2. Run code generation (REQUIRED before any build)
dart run scripts/codegen.dart
```

> **⚠️ Code generation is mandatory.** It generates localization files, emoji data, and database schema code into `lib/generated/`. The `lib/generated/` directory is excluded from version control and must be regenerated locally.

---

## Building

All builds require two `--dart-define` flags:

| Flag | Required Values |
|------|----------------|
| `PLATFORM` | `linux`, `windows`, `android`, `ios`, `macos`, `web`, `desktop`, `mobile` |
| `BUILD_MODE` | `release`, `debug` |

### Platform Build Commands

```bash
cd commet

# Linux
flutter build linux --release --dart-define PLATFORM=linux --dart-define BUILD_MODE=release

# Windows
flutter build windows --release --dart-define PLATFORM=windows --dart-define BUILD_MODE=release

# Android
flutter build apk --debug --dart-define PLATFORM=android --dart-define BUILD_MODE=debug

# Web (requires Rust nightly + ./scripts/prepare-web.sh first)
./scripts/prepare-web.sh
flutter build web --release --dart-define PLATFORM=web --dart-define BUILD_MODE=release
```

### Optional Build Defines

- `GIT_HASH` — Current commit hash (shown on info screen)
- `VERSION_TAG` — Version string for display
- `BUILD_DETAIL` — Build context string (e.g. `"Flatpak"`, `"Snap"`)
- `ENABLE_GOOGLE_SERVICES=true` — Enables Firebase/Google Services variant

---

## Testing

### Unit Tests

```bash
cd commet
flutter test unit_test -d linux --dart-define=BUILD_MODE=release --dart-define=PLATFORM=linux
```

Unit test files are in `commet/unit_test/`:
- `notifying_list_test.dart`
- `password_validator_test.dart`
- `tracking_parameter_test.dart`

### Integration Tests

Integration tests require a local Synapse (Matrix homeserver) instance. Use the provided script:

```bash
cd commet
./scripts/integration-test.sh
```

Required environment variables for integration tests:

```bash
HOMESERVER=localhost
USER1_NAME=alice
USER1_PW=AliceInWonderLand
USER2_NAME=bob
USER2_PW=CanWeFixIt
PROJECT_PATH=commet
```

---

## Linting & Code Style

```bash
cd commet

# Check formatting (non-zero exit if changes needed)
dart format -o none --show all --set-exit-if-changed .

# Static analysis
dart analyze
```

**Analysis configuration** (`commet/analysis_options.yaml`):
- `curly_braces_in_flow_control_structures` is ignored
- Generated files are excluded from analysis (`lib/*.g.dart`, `lib/generated/**`)

---

## CI/CD Workflows

All workflows live in `.github/workflows/`:

| Workflow | Trigger | What it does |
|----------|---------|--------------|
| `static-analysis.yml` | PR, merge_group | Runs `dart format` check + `dart analyze` |
| `build.yml` | PR, merge_group | Builds for Windows, Android, Linux, Web |
| `integration-test.yml` | Push | Full integration tests with Synapse |
| `release.yml` | Release created | Builds and uploads all platform artifacts |
| `benchmark.yml` | PR, workflow_dispatch | Performance benchmarking |
| `copilot-setup-steps.yml` | Manual dispatch | Sets up Copilot dev environment |

When a PR is opened, `static-analysis.yml` and `build.yml` run automatically. Fix any failures in those before considering a PR ready.

---

## Architecture

### Directory Structure (`commet/lib/`)

```
lib/
├── main.dart                  # App entry point
├── client/                    # Matrix client abstraction layer
│   ├── client.dart            # Abstract Client interface
│   ├── client_manager.dart    # Manages multiple client accounts
│   ├── room.dart              # Abstract Room interface
│   ├── space.dart             # Abstract Space interface
│   ├── timeline.dart          # Abstract Timeline interface
│   ├── components/            # Optional/modular client feature components
│   ├── matrix/                # Matrix SDK implementations
│   │   └── matrix_room.dart   # MatrixRoom (concrete Room implementation)
│   ├── matrix_background/     # Background sync implementations
│   │   └── matrix_background_room.dart
│   └── timeline_events/       # Event type definitions
├── config/
│   └── preferences/           # User preferences/settings
├── ui/                        # UI layer (Atomic Design)
│   ├── atoms/                 # Basic components (buttons, text, icons)
│   ├── molecules/             # Composite components
│   ├── organisms/             # Feature-level UI blocks
│   ├── pages/                 # Full-screen pages
│   │   ├── chat/              # Chat view
│   │   ├── login/             # Login flow
│   │   ├── settings/          # Settings pages
│   │   ├── matrix/            # Matrix-specific pages
│   │   └── main/              # Main app shell
│   ├── layout/                # Layout wrappers
│   └── navigation/            # Navigation structure
├── cache/                     # File caching utilities
├── debug/                     # Logging (Log class)
├── diagnostic/                # Diagnostics and mocks
├── generated/                 # ⚠️ Auto-generated (not in git)
│   └── l10n/                  # Localization
├── generator/                 # Custom code generators (emoji builder)
├── service/                   # Background services
└── utils/                     # Utilities
    ├── database/              # Drift ORM database
    ├── emoji/                 # Emoji handling
    ├── image/                 # Image processing
    └── links/                 # Link handling
```

### Key Patterns

- **Abstract client interfaces** are defined in `commet/lib/client/`. Matrix-specific implementations live in `commet/lib/client/matrix/`.
- **UI follows Atomic Design**: atoms → molecules → organisms → pages.
- **Tiamat** (`tiamat/`) is the custom design system. Use its components rather than raw Material widgets for UI consistency.
- **Provider** is used for state management throughout the app.
- **Global singletons** are initialized in `main.dart`: `navigator`, `preferences`, `clientManager`, `backgroundTaskManager`.
- **Components** in `client/components/` are optional modular features (e.g. emoji, GIF, polls, threads) that can be attached to a client.

### Localization

Localization is ARB-based (in `commet/assets/l10n/`). After adding or modifying strings, regenerate with:

```bash
cd commet
dart run scripts/codegen.dart
```

Access localized strings via `AppLocalizations.of(context)`.

---

## Dependencies

Key packages used in the main app:

| Package | Purpose |
|---------|---------|
| `provider` | State management |
| `drift` / `sqflite` | SQLite ORM / database |
| `media_kit` | Video/audio playback |
| `flutter_markdown` | Markdown rendering |
| `flutter_svg` | SVG support |
| `url_launcher` | Opening external URLs |
| `path_provider` | Platform file paths |
| `shared_preferences` | Lightweight key-value storage |
| `window_manager` | Desktop window management |
| `desktop_notifications` | Native desktop notifications |
| `unifiedpush` | Push notifications (Android) |
| `http` | HTTP client |

Some packages are forks hosted under the `commetchat` GitHub org (e.g. `flutter_html`, `flutter_highlighter`).

---

## Common Pitfalls

1. **Never skip code generation.** Any build without `dart run scripts/codegen.dart` will fail because `lib/generated/` doesn't exist in the repository.

2. **Always specify `--dart-define PLATFORM=...`** when running or building. Many UI and feature branches are gated on platform checks at runtime.

3. **Android builds need disk space cleanup** on CI. The `build.yml` workflow removes unused toolchains before checkout. If you hit disk-space errors locally, free up space first.

4. **Web builds need Rust.** Run `./scripts/prepare-web.sh` before building for web. This installs a Rust nightly toolchain with `rust-src`.

5. **Generated files should not be committed.** The `.gitignore` excludes `lib/generated/`. Do not add generated files to commits.

6. **Code style checks are enforced by CI.** Run `dart format -o none --show all --set-exit-if-changed .` and `dart analyze` before pushing.

---

## AI Contribution Guidelines

Per the project's `CONTRIBUTING.md`, AI-generated contributions should be used only as a development aid. Contributors are expected to:

- Fully understand and be able to explain every proposed change
- Add personal value and expertise beyond raw AI output
- Not post raw LLM output as GitHub comments or issue responses

---

## Useful Scripts

All scripts are in `commet/scripts/`:

| Script | Purpose |
|--------|---------|
| `codegen.dart` | Runs all code generation (localization, emoji, DB schema) |
| `integration-test.sh` | Spins up Synapse and runs integration tests |
| `prepare-web.sh` | Installs Rust nightly for web builds |
| `setup_android_release.dart` | Configures Android signing for release builds |
| `apply_google_services.patch` | Applies Firebase/Google Services patch |
