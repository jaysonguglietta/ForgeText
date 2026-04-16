# ForgeText

ForgeText is a native macOS text editor built for serious text work: plain text, code, logs, config files, structured data, and operational documents that need both raw editing and thoughtful inspection.

The app uses `NSTextView` under SwiftUI for mature macOS editing behavior, but the current shell is intentionally styled like a late-90s web workbench: beveled panels, bright portal accents, monospaced chrome, and a retro control surface wrapped around a native editor core.

## Current version

- Current tagged release: `V1.0.1`
- Current app bundle version in the local build: `1.0 (1)`

## What's new in V1.0.1

- Git branch, changed-file, and stash refresh now run through async Git workspace snapshots instead of blocking SwiftUI view layout on the main thread
- This specifically hardens the editor against crashes while rendering Git-heavy menus and workspace chrome
- ForgeText now includes a dedicated `./Scripts/build_release_dmg.sh` packaging flow for GitHub Releases
- The release and updater docs now explain the recommended DMG-plus-GitHub-Releases distribution path more clearly

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

### Workspace platform

- Workspace Center for managing active roots, trust mode, saved profiles, sync bundles, and registry sources
- Multi-root workspaces with `.forgetext-workspace` files, active-root switching, and session restore
- Workspace Trust / Restricted Mode so tasks, AI actions, remote commands, and external plugins can be gated in safer folders
- Saved workspace profiles for theme, font, plugin, explorer, and AI context preferences
- Portable mode support through a sibling `ForgeTextData` directory or `FORGETEXT_PORTABLE_DATA_DIR`
- Sync bundle export/import for settings, workspace sessions, and AI sessions
- Curated plus custom plugin registries with install, remove, enable, disable, and refresh flows

### IDE and plugin features

- Built-in plugin manager with enable/disable controls for first-party IDE extensions
- External plugin manifest loading from workspace and user plugin folders
- Plugin-backed snippet library for JSON, Markdown, Swift, shell, Python, JavaScript, XML, SQL, CSS, and config files
- Workspace task runner that detects SwiftPM, npm, Python, and Make-based build/test/lint commands
- Problems panel with compiler-style output matching for build, test, lint, and terminal output
- Test explorer for running detected test tasks, coverage-aware runs, and reviewing the latest run
- Lightweight diagnostics for malformed JSON/XML/CSV/config/HTTP files plus TODO/FIXME markers
- Secret-aware warnings for private keys, bearer tokens, and likely credentials
- Git-aware status pills, repository cloning, fetch/pull/push, commit drafting, branch creation, stash flows, compare-with-HEAD, diff-gutter markers, recent graph history, remotes, and merge-conflict resolution helpers
- Inline editor insight bar for current-line diagnostics and Git blame context
- Format-document support for JSON, XML, HTTP, and toolchain-backed language formatting when available

### AI workbench

- Provider-neutral AI profiles for OpenAI, Anthropic, Gemini, Ollama, and OpenAI-compatible endpoints
- Workspace rule ingestion from files like `AGENTS.md`, `CLAUDE.md`, `.cursorrules`, and `.forgetext/ai-rules.md`
- Chat sessions with reusable prompts, provider/model switching, and response history
- Quick AI actions for explain, improve, generate tests, summarize file, and draft commit message
- Insert-at-cursor and replace-selection flows from the latest AI response

### CLI

- `Scripts/forgetext` launcher for opening ForgeText from Terminal
- Supports workspace files, profile selection, diff mode, and `file:line` shortcuts
- Simple file/folder opens route through macOS `open`; advanced flags launch ForgeText with direct CLI arguments

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
- `Scripts/`: helper scripts for app icon generation, local release builds, DMG packaging, the `forgetext` CLI launcher, and utility tasks
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

## CLI launcher

Once ForgeText is built or installed, you can launch it from Terminal with:

```bash
./Scripts/forgetext
```

Open a file:

```bash
./Scripts/forgetext ~/projects/app/README.md
```

Jump to a line:

```bash
./Scripts/forgetext ~/projects/app/Sources/main.swift:42
```

Open a saved multi-root workspace:

```bash
./Scripts/forgetext --workspace ~/projects/ops.forgetext-workspace
```

Open a side-by-side compare:

```bash
./Scripts/forgetext --diff left.txt right.txt
```

If you keep ForgeText somewhere other than `/Applications`, point the launcher at it with:

```bash
FORGETEXT_APP=/path/to/ForgeText.app ./Scripts/forgetext --help
```

## Public GitHub download flow


Build a GitHub Release-ready DMG with:

```bash
./Scripts/build_release_dmg.sh
```

That writes a versioned DMG to:

```text
dist/ForgeText-1.0-1.dmg
```

You can reveal it in Finder with:

```bash
./Scripts/build_release_dmg.sh --open
```

Recommended distribution flow:

1. Build the DMG with `./Scripts/build_release_dmg.sh`
2. Create a GitHub Release such as `V1.0.1`
3. Upload the DMG as a release asset
4. Point Sparkle's appcast entry at that release asset URL

Notes:

- Use GitHub Releases for downloadable binaries; do not commit generated DMGs to `main`
- For public distribution, the app and DMG should eventually be Developer ID signed and notarized
- The updater feed lives at `https://jaysonguglietta.github.io/ForgeText/appcast.xml`

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
