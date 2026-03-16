# Copilot Coding Agent Instructions

## Project Overview

**Commet** is an open-source Matrix chat client built with Flutter/Dart. It targets Linux, Windows, Android, and Web (macOS/iOS are future work). The app wraps a custom fork of the `matrix-dart-sdk` and exposes a feature-rich UI including end-to-end encryption, spaces, threads, custom emoji/stickers, and push notifications.

The repository is a **Dart workspace** containing four packages:

| Directory | Role |
|-----------|------|
| `commet/` | Main Flutter application (primary package) |
| `tiamat/` | Custom Material Design wrapper library used by the app |
| `widgets/matrix_widget_api/` | Matrix widget API library |
| `widgets/calendar/` | Calendar widget library |

---

## Tech Stack

- **Language**: Dart (null-safe, SDK `>=3.6.0 <4.0.0`)
- **Framework**: Flutter 3.41.1 (stable channel)
- **State management**: Provider 6.x
- **Database**: Drift 2.x (SQLite via `sqflite_common_ffi` on desktop)
- **Matrix SDK**: Custom fork of `matrix-dart-sdk` (referenced via git)
- **Code generation**: `build_runner`, `intl_utils`, `intl_translation`
- **Localization**: ARB files in `commet/assets/l10n/`, generated output in `commet/lib/generated/l10n/`
- **CI**: GitHub Actions (Flutter 3.41.1, JDK 17 for Android)

---

## Directory Structure (commet/)

```
commet/lib/
├── cache/              # File caching utilities
├── client/             # Matrix client implementation
│   ├── components/     # Client plugins (push notifications, encryption, etc.)
│   ├── matrix/         # Wrappers around matrix-dart-sdk
│   └── timeline/       # Message/event handling
├── config/             # Build configuration and user preferences
│   ├── build_config.dart   # Reads dart-define constants at compile time
│   └── preferences.dart    # Shared preferences wrapper
├── debug/              # Debug logging utilities
├── service/            # Background services
├── ui/                 # UI layer (atomic design)
│   ├── atoms/          # Small, reusable widgets
│   ├── molecules/      # Compositions of atoms
│   ├── organisms/      # Complex self-contained sections
│   ├── pages/          # Full-screen views
│   ├── layout/         # Layout helpers
│   └── navigation/     # Navigation logic
├── utils/              # General utilities (emoji, database, shortcuts, etc.)
└── main.dart           # App entry point
```

Generated files (`*.g.dart`, `lib/generated/`) are **git-ignored** and must be produced locally before building.

---

## Essential First Steps (before building)

All commands below should be run from the `commet/` directory unless noted.

### 1. Fetch dependencies

```bash
cd commet
flutter pub get
```

### 2. Run code generation (REQUIRED — do this before every build)

```bash
dart run scripts/codegen.dart
```

This script:
1. Runs `flutter pub get`
2. Generates localization Dart files from `.arb` sources via `intl_utils` and `intl_translation`
3. Runs `build_runner build` to generate `*.g.dart` files (emoji data, Drift DB, etc.)

Skipping this step will cause compile-time errors because the generated files are not committed to the repository.

---

## Building

All `flutter build` / `flutter run` commands require two mandatory `--dart-define` flags:

| Flag | Values | Notes |
|------|--------|-------|
| `PLATFORM` | `linux`, `windows`, `android`, `web`, `ios`, `macos`, `desktop`, `mobile` | Selects platform-specific code paths |
| `BUILD_MODE` | `debug`, `release` | Controls release optimisations |

Optional flags: `GIT_HASH`, `VERSION_TAG`, `BUILD_DETAIL`, `ENABLE_GOOGLE_SERVICES`, `BUILD_DATE`, `COMMET_PROD`.

### Common build commands

```bash
# Linux desktop (release)
flutter build linux --release \
  --dart-define PLATFORM=linux \
  --dart-define BUILD_MODE=release

# Android debug APK
flutter build apk --debug \
  --dart-define PLATFORM=android \
  --dart-define BUILD_MODE=debug

# Web release
flutter build web --release \
  --dart-define PLATFORM=web \
  --dart-define BUILD_MODE=release
```

### Windows note

Long paths must be enabled before building on Windows:

```bash
git config --global core.longpaths true
```

### Linux system dependencies

```bash
sudo apt-get install -y ninja-build libgtk-3-dev libmpv-dev mpv ffmpeg libmimalloc-dev
```

---

## Running locally

```bash
# Linux
flutter run --dart-define BUILD_MODE=debug --dart-define PLATFORM=linux

# Android (device/emulator must be connected)
flutter run --dart-define BUILD_MODE=debug --dart-define PLATFORM=android
```

### Widgetbook (component explorer)

```bash
scripts/run_widgetbook.sh
# or manually:
flutter run -d linux lib/main.widgetbook.dart
```

---

## Testing

### Unit tests

```bash
# Using the helper script (sets required dart-defines):
scripts/unit-test.sh

# Or directly (HOMESERVER defaults to localhost):
flutter test unit_test -d linux \
  --dart-define=HOMESERVER=localhost \
  --dart-define=BUILD_MODE=release
```

Unit tests live in `commet/unit_test/`.

### Integration tests (requires Docker / Synapse)

```bash
# 1. Start a local Synapse homeserver
scripts/integration-server-synapse.sh

# 2. Create test users
scripts/integration-prepare-homeserver.sh

# 3. Run tests
scripts/integration-test.sh
```

Integration tests live in `commet/integration_test/`. They are only run on push (not on pull requests) in CI due to setup overhead.

### Test environment variables

| Variable | Purpose |
|----------|---------|
| `HOMESERVER` | Test server address (default: `localhost`) |
| `USER1_NAME` | Test user 1 name (CI default: `alice`) |
| `USER1_PW` | Test user 1 password |
| `USER2_NAME` | Test user 2 name (CI default: `bob`) |
| `USER2_PW` | Test user 2 password |

---

## Linting and Formatting

```bash
# Check formatting (no changes written):
dart format -o none --show all --set-exit-if-changed .

# Apply formatting:
dart format .

# Static analysis:
dart analyze
```

Linter configuration is in `commet/analysis_options.yaml`. Notable settings:
- `curly_braces_in_flow_control_structures` is set to `ignore`
- Excludes: `*.g.dart`, `lib/generated/**`, `lib/main.widgetbook.dart`, `integration_test/**`

---

## CI Workflows

| Workflow file | Trigger | What it does |
|---------------|---------|--------------|
| `build.yml` | PR, merge_group | Parallel builds for Windows, Android, Linux, Web |
| `static-analysis.yml` | PR, merge_group | `dart format` check + `dart analyze` |
| `integration-test.yml` | Push | Unit tests + integration tests with Synapse |
| `release.yml` | Release / manual | Builds and uploads release artifacts |
| `benchmark.yml` | PR, merge_group, manual | Performance benchmarking (350 % alert threshold) |

CI uses Flutter 3.41.1 and JDK 17. Android jobs include an aggressive disk-space cleanup step to prevent out-of-disk failures.

---

## Coding Conventions

### File / symbol naming
- Files: `snake_case.dart`
- Classes / enums: `PascalCase`
- Variables / methods: `camelCase`
- Compile-time constants (`dart-define` vars): `UPPER_SNAKE_CASE`

### UI architecture (atomic design)
New widgets belong in:
- `atoms/` — single-purpose, highly reusable
- `molecules/` — combinations of atoms
- `organisms/` — complex, self-contained sections
- `pages/` — full-screen views

### Platform-specific code
Use `BuildConfig` constants (set via `--dart-define`) rather than `Platform.*` checks where possible. `BuildConfig` is the source of truth for `PLATFORM` and `BUILD_MODE` values.

### Generated code
Never edit `*.g.dart` files by hand. Re-run `dart run scripts/codegen.dart` after changing:
- ARB localization files (`assets/l10n/*.arb`)
- Drift database schemas
- Emoji data (`assets/emoji_data/data.json`)
- Any class annotated with a build_runner generator

### Localization
Add new strings to the English ARB file first (`assets/l10n/intl_en.arb`), then run codegen. Do not add strings directly to generated files.

### Dependency changes
- Prefer packages already present in `pubspec.yaml`
- If adding a new pub.dev package, verify it supports all target platforms
- Several dependencies are **git-based forks** — do not silently replace them with pub.dev versions

---

## Key Configuration Files

| File | Purpose |
|------|---------|
| `commet/pubspec.yaml` | App dependencies and Flutter metadata |
| `commet/analysis_options.yaml` | Dart linter / analyzer rules |
| `commet/build.yaml` | Custom build_runner builders (emoji data) |
| `commet/l10n.yaml` | Localization ARB configuration |
| `commet/lib/config/build_config.dart` | Reads `dart-define` compile-time constants |
| `pubspec.yaml` (root) | Dart workspace definition |
| `flake.nix` (root) | Optional Nix dev environment |

---

## Known Gotchas and Workarounds

1. **Missing generated files**: If you see import errors for files ending in `.g.dart` or paths containing `lib/generated/`, run `dart run scripts/codegen.dart` from `commet/`.

2. **Dart-define missing**: Omitting `--dart-define PLATFORM=...` or `--dart-define BUILD_MODE=...` causes runtime assertion errors. Always supply both.

3. **Windows long paths**: Flutter/Dart on Windows can fail with path-too-long errors. Run `git config --global core.longpaths true` before cloning or building.

4. **Disk space on CI**: Android builds exhaust GitHub-hosted runner disk space. The `build.yml` workflow removes .NET, Haskell, Julia, and other large pre-installed tools before building.

5. **analyzer version override**: `pubspec.yaml` pins `analyzer: ^7.3.0` via `dependency_overrides` for compatibility — do not remove this override.

6. **markdown fork**: The `markdown` package is forked to fix https://github.com/dart-lang/tools/issues/2169. Do not replace it with the upstream pub.dev version.

7. **Firebase disabled by default**: `ENABLE_GOOGLE_SERVICES` defaults to `false`. The `google-services.json` file is git-ignored. Firebase is only used for Android push notifications in production builds.

8. **Integration tests record video**: On failure, integration tests write a video to `commet/video.mkv` for debugging.

---

## AI / Generative AI Policy

Per `CONTRIBUTING.md`:
- Do **not** post LLM/AI-generated text as GitHub issue or PR comments.
- AI tools may be used as coding aids, but the developer must fully understand and be able to explain every proposed change.
- Low-value or entirely AI-generated contributions will be rejected and repeated offenders may be blocked.

When acting as a coding agent on this repository, ensure all changes are purposeful, well-understood, minimal, and explained clearly in PR descriptions.
