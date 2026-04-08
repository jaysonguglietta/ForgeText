# ForgeText

ForgeText is a native macOS text editor built for serious text work: plain text, code, logs, config files, structured data, and operational documents that need both raw editing and thoughtful inspection.

The app uses `NSTextView` under SwiftUI for mature macOS editing behavior, but the current shell is intentionally styled like a late-90s web workbench: beveled panels, bright portal accents, monospaced chrome, and a retro control surface wrapped around a native editor core.

## Current capabilities

### Core editing

- AppKit-backed editor surface with undo, line numbers, status metrics, and theme-aware typing
- Multi-document tabs plus a document sidebar
- New, open, save, save as, close, revert-to-saved, and dirty-state protection flows
- Find/replace, regex search, go-to-line, project search, and a command palette
- Language detection, lightweight syntax highlighting, comment toggling, indentation helpers, and bracket matching
- Theme switching, wrap toggle, font sizing, breadcrumbs, outline panel, and split-pane workspace modes

### File reliability

- Encoding detection and preservation for common text encodings
- BOM handling and line-ending detection/preservation
- Autosave recovery, session restore, and crash-recovery snapshots
- External file-change detection with reload/keep-mine flows
- Safer large-file handling, read-only previews, and binary hex fallback
- Archive browsing and follow-mode handling for log-style files

### Structured views

- CSV and delimited files as table views
- JSON as a tree view
- Logs as a log explorer
- Config-oriented structured inspection support in the workbench model
- Fast toggles between structured views and raw text

### macOS workflows

- Finder/open-document handling for supported file types
- Local release build/install workflow for `/Applications`
- Terminal handoff, workspace sessions, recent files, and recent remote locations

## Retro UI direction

The current ForgeText shell intentionally leans into a "late-90s web app for power users" vibe:

- beveled panels instead of glassy cards
- cyan, magenta, gold, and cream portal colors
- monospaced chrome and labels
- striped rules, inset form fields, and loud utility surfaces
- a playful retro wrapper around a modern native Mac editor engine

This is not a temporary joke skin. It is now part of the product direction for the local workbench UI.

## Project layout

- `project.yml`: XcodeGen project definition
- `ForgeText/`: application source
- `ForgeTextTests/`: unit tests
- `Scripts/`: helper scripts for app icon generation, local release builds, and utility tasks
- `docs/`: product and UI planning docs

## Build and run

1. Generate the Xcode project:

   ```bash
   xcodegen generate
   ```

2. Open it in Xcode:

   ```bash
   open ForgeText.xcodeproj
   ```

3. Or build from the terminal with the full Xcode toolchain:

   ```bash
   DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
   xcodebuild \
     -project ForgeText.xcodeproj \
     -scheme ForgeText \
     -derivedDataPath DerivedData \
     build
   ```

4. If you want to refresh generated app icon assets:

   ```bash
   swift -module-cache-path .build/ModuleCache Scripts/generate_app_icon.swift
   ```

## Local install for your Mac

If ForgeText is just for your own Mac, you do not need a DMG, notarization, or distribution packaging.

Build a local `Release` app with:

```bash
./Scripts/build_local_release.sh
```

Install it into `/Applications` with:

```bash
./Scripts/build_local_release.sh --install
```

Build, install, and launch in one step with:

```bash
./Scripts/build_local_release.sh --install --open
```

This produces a shareable local app bundle at:

```text
DerivedData/Build/Products/Release/ForgeText.app
```

Notes:

- This workflow is for local use on your own Mac.
- It skips DMG packaging and Apple notarization.
- The installed app lives at `/Applications/ForgeText.app` when `--install` is used.

## Testing

Build verification from the terminal:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild \
  -project ForgeText.xcodeproj \
  -scheme ForgeText \
  -derivedDataPath DerivedData \
  build
```

Run tests:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild \
  -project ForgeText.xcodeproj \
  -scheme ForgeText \
  -derivedDataPath DerivedData \
  test
```

## Current product focus

ForgeText is already beyond a starter app. The next meaningful pushes are about depth and polish:

- richer structured viewers for YAML, TOML, env files, and archives
- stronger system-engineer workflows like privileged save and remote editing
- higher-end table, log, and compare tooling
- accessibility, packaging, updater flow, and release hardening

## Product docs

- [ROADMAP.md](/Users/jaysonguglietta/SynologyDrive/Drive/apps/texteditor/docs/ROADMAP.md): product roadmap and release priorities
- [UI_WORKBENCH_PLAN.md](/Users/jaysonguglietta/SynologyDrive/Drive/apps/texteditor/docs/UI_WORKBENCH_PLAN.md): UI direction and workbench plan
