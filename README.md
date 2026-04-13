# ForgeText

ForgeText is a native macOS text editor built for serious text work: plain text, code, logs, config files, structured data, and operational documents that need both raw editing and thoughtful inspection.

The app uses `NSTextView` under SwiftUI for mature macOS editing behavior, but the current shell is intentionally styled like a late-90s web workbench: beveled panels, bright portal accents, monospaced chrome, and a retro control surface wrapped around a native editor core.

## ForgeText 1.0 workbench

ForgeText 1.0 centers around twenty core capabilities:

1. Native multi-document editing with tabs, sidebar navigation, and split-pane layouts
2. Reliable open/save/revert flows with dirty-state protection
3. Encoding, BOM, and line-ending preservation
4. Crash recovery, autosave recovery, and session restore
5. Find/replace, regex search, go-to-line, project search, and command palette
6. Language detection, predictive completions, syntax highlighting, and editing assists
7. Structured viewers for CSV, JSON, logs, HTTP, and config formats
8. Large-file preview, binary hex fallback, archive browsing, and log follow mode
9. Workspace explorer with favorites and filtering
10. Embedded terminal and terminal handoff
11. Workspace task runner for build, test, and lint workflows
12. Problems panel with compiler-style matcher support
13. Test explorer for detected test tasks and recent run output
14. Git clone and local repository workspace activation
15. Git workbench with fetch, pull, push, commit, branch, stash, stage, and unstage flows
16. Git-aware compare, diff markers, blame context, and status surfaces
17. Plugin manager plus external plugin manifest loading
18. Snippets, lightweight diagnostics, formatting hooks, and secret-aware checks
19. Provider-neutral AI workbench with workspace rules, chat sessions, and quick actions
20. Native macOS local install workflow with a distinct retro-web shell

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
- YAML, TOML, `.env`, and related config files through the structured config inspector
- HTTP request files as a runnable request workbench with response inspection
- Fast toggles between structured views and raw text

### macOS workflows

- Finder/open-document handling for supported file types
- Clone GitHub or other Git repositories directly into a local workspace folder
- Public-release update scaffolding with a built-in `Check for Updates...` command backed by Sparkle
- Local release build/install workflow for `/Applications`
- Workspace explorer with favorites and file filtering
- Embedded terminal console inside ForgeText
- Terminal handoff, workspace sessions, recent files, and recent remote locations
- Remote file open, remote grep, and remote command execution over SSH-style connections

### IDE and plugin features

- Built-in plugin manager with enable/disable controls for first-party IDE extensions
- External plugin manifest loading from workspace and user plugin folders
- Plugin-backed snippet library for JSON, Markdown, Swift, shell, Python, JavaScript, XML, SQL, CSS, and config files
- Workspace task runner that detects SwiftPM, npm, Python, and Make-based build/test/lint commands
- Problems panel with compiler-style output matching for build, test, lint, and terminal output
- Test explorer for running detected test tasks and reviewing the latest run
- Lightweight diagnostics for malformed JSON/XML/CSV/config/HTTP files plus TODO/FIXME markers
- Secret-aware warnings for private keys, bearer tokens, and likely credentials
- Git-aware status pills, repository cloning, fetch/pull/push, commit drafting, branch creation, stash flows, compare-with-HEAD, and diff-gutter markers
- Inline editor insight bar for current-line diagnostics and Git blame context
- Format-document support for JSON, XML, HTTP, and toolchain-backed language formatting when available

### AI workbench

- Provider-neutral AI profiles for OpenAI, Anthropic, Gemini, Ollama, and OpenAI-compatible endpoints
- Workspace rule ingestion from files like `AGENTS.md`, `CLAUDE.md`, `.cursorrules`, and `.forgetext/ai-rules.md`
- Chat sessions with reusable prompts, provider/model switching, and response history
- Quick AI actions for explain, improve, generate tests, summarize file, and draft commit message
- Insert-at-cursor and replace-selection flows from the latest AI response

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

## Post-1.0 focus

ForgeText is now in a credible 1.0 state. The next meaningful pushes are about depth and polish:

- parser-backed language packs and deeper formatter/linter integrations
- richer GitHub and remote collaboration workflows
- stronger system-engineer workflows like privileged save and richer remote editing
- higher-end table, log, compare, explorer, diagnostics, and testing tooling
- accessibility, packaging, updater flow, and release hardening

## Product docs

- [ROADMAP.md](/Users/jaysonguglietta/SynologyDrive/Drive/apps/texteditor/docs/ROADMAP.md): product roadmap and release priorities
- [UI_WORKBENCH_PLAN.md](/Users/jaysonguglietta/SynologyDrive/Drive/apps/texteditor/docs/UI_WORKBENCH_PLAN.md): UI direction and workbench plan
- [UPDATES.md](/Users/jaysonguglietta/SynologyDrive/Drive/apps/texteditor/docs/UPDATES.md): GitHub Pages + Sparkle release update setup
