# ForgeText

ForgeText is a native macOS text editor starter focused on being a strong foundation for a more capable editor. It uses `NSTextView` under SwiftUI so we get mature macOS text behavior from the start instead of fighting the limits of the basic `TextEditor` control.

## What is included

- Native macOS app scaffold generated with XcodeGen
- AppKit-backed editing surface with undo, multi-document tabs, and a document sidebar
- Open, save, save as, close, and revert-to-saved flows
- Dirty-state protection before destructive actions
- Encoding detection for common text encodings
- Line-ending detection and preservation on save
- Line number gutter and a status bar with cursor metrics
- Find and replace, go-to-line, and a command palette
- Theme switching, language modes, and lightweight syntax highlighting
- Recent files, session restore, autosave recovery, and external file-change detection
- Structured file viewers for CSV tables, JSON trees, and log exploration
- Scripted app icon generation for the ForgeText brand

## Project layout

- `project.yml`: XcodeGen project definition
- `ForgeText/`: app source
- `ForgeTextTests/`: unit tests for file codec behavior

## Getting started

1. Generate the project:

   ```bash
   xcodegen generate
   ```

2. Generate the app icon assets:

   ```bash
   swift -module-cache-path .build/ModuleCache Scripts/generate_app_icon.swift
   ```

3. Open the app in Xcode:

   ```bash
   open ForgeText.xcodeproj
   ```

4. Or build from the terminal:

   ```bash
   DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
   xcodebuild -project ForgeText.xcodeproj -scheme ForgeText -derivedDataPath DerivedData build
   ```

## Local install for your Mac

If you just want ForgeText installed on your own Mac, you can skip DMGs, notarization, and sharing-related steps.

Build a cleaner local `Release` app with:

```bash
./Scripts/build_local_release.sh
```

That produces:

```text
DerivedData/Build/Products/Release/ForgeText.app
```

If you want the script to copy it into `/Applications` for you:

```bash
./Scripts/build_local_release.sh --install
```

If you want it to build, install, and then launch:

```bash
./Scripts/build_local_release.sh --install --open
```

Notes:

- This is for local use on your own Mac.
- It does not create a DMG.
- It does not notarize or prepare the app for public distribution.
- You can still open [ForgeText.app](/Users/jaysonguglietta/SynologyDrive/Drive/apps/texteditor/DerivedData/Build/Products/Release/ForgeText.app) directly after the build.

## Good next steps

- Add split editing or multi-window workflows
- Add richer file-aware viewers for YAML, TOML, env files, and archives
- Add symbol outline, breadcrumbs, and split-pane workbench polish
- Add privileged-save and remote editing workflows for system engineers
- Add an extension or plugin story once the core model is stable

## Product docs

- `docs/ROADMAP.md`: production roadmap for system-engineer workflows
- `docs/UI_WORKBENCH_PLAN.md`: UI and workbench direction for ForgeText
