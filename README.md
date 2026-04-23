# ForgeText

ForgeText is a native macOS text editor for serious text work: plain text, code, logs, config files, structured data, Git workflows, AI-assisted editing, and operational documents that need both raw editing and thoughtful inspection.

The app uses `NSTextView` under SwiftUI for mature macOS editing behavior. The shell intentionally looks like a late-90s web workbench: beveled panels, cream/cyan/pink/gold accents, monospaced labels, and a playful portal-era control surface wrapped around a native editor core.

## Current Version

- Current app bundle version: `1.2 (3)`
- Last public tag in this repository: `V1.0.1`
- Local install path after `--install`: `/Applications/ForgeText.app`

ForgeText 1.1 adds the new productivity layer: Quick Open, workspace indexing, command palette modes, Activity Center, AI Context Center, GitHub Workflow, Release Readiness, Performance HUD, Theme Lab, First-Run Setup, and diagnostic bundle export.

## Highlights

- Native multi-document editing with tabs, sidebar navigation, split panes, line numbers, undo, status metrics, and raw text editing.
- Safe file handling with encoding, BOM, line-ending preservation, crash recovery, autosave recovery, session restore, and external-change detection.
- File-aware structured views for CSV/delimited files, JSON, logs, HTTP request files, config formats, archives, large-file previews, and binary hex fallback.
- Developer workbench features: workspace explorer, project search, Quick Open, command palette, embedded terminal, task runner, problems panel, test explorer, Git workbench, and plugin manager.
- Workspace indexing for fast file and symbol navigation, TODO/FIXME discovery, and lightweight warning counts.
- Provider-neutral AI workbench with model profiles, workspace rules, reusable prompt files, chat sessions, and editor quick actions.
- Git and GitHub helpers for clone, branch/status flows, compare-with-HEAD, diff markers, blame context, GitHub remote detection, and compare-page launch.
- Production helpers for release readiness, Sparkle update configuration, performance snapshots, and safe diagnostic bundle export.

## ForgeText 1.1 Productivity Layer

The 1.1 workbench adds a control-center layer for larger developer workflows:

1. Quick Open for indexed workspace files and symbols.
2. Command Palette 2.0 with `> commands`, `@ files`, and `# symbols` search modes.
3. Workspace Indexer for files, symbols, TODO/FIXME/HACK markers, and likely secret warnings.
4. Activity Center for recent editor, index, release, Git, and diagnostic events.
5. First-Run Setup checklist for workspace, AI, plugins, update readiness, and appearance.
6. AI Context Center for `.forgetext/rules.md`, `.forgetext/ai-rules.md`, `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, `CODEX.md`, `.cursorrules`, and `.forgetext/prompts/*.md`.
7. GitHub Workflow panel for detected GitHub remotes and compare/PR preparation links.
8. Release Readiness panel for version, Sparkle feed/key, appcast, release docs, build script, and DMG checks.
9. Performance HUD for open documents, workspace roots, index size, plugins, tasks, memory, and uptime.
10. Theme Lab for the retro chrome style, density, editor theme, focus mode, and inspector.
11. Diagnostic Bundle export that avoids document contents and AI API keys.

## User Help

Start with the help guide:

- [ForgeText Help](docs/HELP.md)

Useful feature paths:

- `Search > Quick Open...` or `Command-P`
- `Search > Command Palette...` or `Command-Shift-P`
- `Tools > Activity Center`
- `Tools > First-Run Setup`
- `Tools > AI Context Center`
- `Tools > Release Readiness`
- `Tools > Performance HUD`
- `Tools > Export Diagnostic Bundle...`

Command palette prefixes:

- `>` searches commands, settings, tasks, plugins, themes, and actions.
- `@` searches open documents, recent files, and indexed workspace files.
- `#` searches indexed symbols.

## Current Capabilities

### Core Editing

- AppKit-backed editor surface with undo, line numbers, status metrics, and theme-aware typing.
- Multi-document tabs plus a document sidebar.
- New, open, save, save as, close, revert-to-saved, and dirty-state protection flows.
- Find/replace, regex search, go-to-line, project search, Quick Open, and command palette.
- Language detection, lightweight syntax highlighting, comment toggling, indentation helpers, and bracket matching.
- Theme switching, wrap toggle, font sizing, breadcrumbs, outline panel, inspector, focus mode, and split-pane workspace modes.

### File Reliability

- Encoding detection and preservation for common text encodings.
- BOM handling and line-ending detection/preservation.
- Autosave recovery, session restore, and crash-recovery snapshots.
- External file-change detection with reload/keep-mine flows.
- Safer large-file handling, read-only previews, and binary hex fallback.
- Archive browsing and follow-mode handling for log-style files.

### Structured Views

- CSV and delimited files as table views.
- JSON as a tree view.
- Logs as a log explorer.
- YAML, TOML, `.env`, INI, plist, and related config files through the structured config inspector.
- HTTP request files as a runnable request workbench with response inspection.
- Fast toggles between structured views and raw text.

### Workspace Platform

- Workspace Center for managing active roots, trust mode, saved profiles, sync bundles, and registry sources.
- Multi-root workspaces with `.forgetext-workspace` files, active-root switching, and session restore.
- Workspace Trust / Restricted Mode so tasks, AI actions, remote commands, and external plugins can be gated in safer folders.
- Workspace explorer with favorites and filtering.
- Workspace index for Quick Open, symbol search, TODO counts, and warning counts.
- Portable mode through a sibling `ForgeTextData` directory or `FORGETEXT_PORTABLE_DATA_DIR`.
- Sync bundle export/import for settings, workspace sessions, and AI sessions.

### IDE And Plugin Features

- Built-in plugin manager with enable/disable controls for first-party IDE extensions.
- External plugin manifest loading from workspace and user plugin folders.
- Plugin-backed snippet library for JSON, Markdown, Swift, shell, Python, JavaScript, XML, SQL, CSS, and config files.
- Workspace task runner that detects SwiftPM, npm, Python, and Make-based build/test/lint commands.
- Problems panel with compiler-style output matching for build, test, lint, and terminal output.
- Test explorer for running detected test tasks, coverage-aware runs, and reviewing latest output.
- Lightweight diagnostics for malformed JSON/XML/CSV/config/HTTP files plus TODO/FIXME markers.
- Secret-aware warnings for private keys, bearer tokens, and likely credentials.
- Format-document support for JSON, XML, HTTP, and toolchain-backed language formatting when available.

### Git And GitHub

- Clone GitHub or other Git repositories directly into a local workspace folder.
- Git workbench with fetch, pull, push, commit, branch, stash, stage, unstage, graph, and remote flows.
- Compare-with-HEAD, diff-gutter markers, current-line Git blame context, and merge-conflict helpers.
- GitHub Workflow panel that detects GitHub remotes and opens repository or compare pages for PR preparation.

### AI Workbench

- Provider-neutral AI profiles for OpenAI, Anthropic, Gemini, Ollama, and OpenAI-compatible endpoints.
- Workspace rule ingestion from `.forgetext/rules.md`, `.forgetext/ai-rules.md`, `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, `CODEX.md`, `.github/copilot-instructions.md`, and `.cursorrules`.
- Reusable prompt files from `.forgetext/prompts/*.md`, `.txt`, or `.prompt`.
- Chat sessions with reusable prompts, provider/model switching, and response history.
- Quick AI actions for explain, improve, generate tests, summarize file, and draft commit message.
- Insert-at-cursor and replace-selection flows from the latest AI response.

### Production Helpers

- Activity Center for recent app and workspace events.
- Release Readiness panel for Sparkle and DMG release checks.
- Performance HUD for a lightweight local health snapshot.
- Safe diagnostic bundle export for support and debugging.
- Sparkle update scaffolding with `Check for Updates...`.

## Build And Run

Generate the Xcode project:

```bash
xcodegen generate
```

Open it in Xcode:

```bash
open ForgeText.xcodeproj
```

Build from Terminal with the full Xcode toolchain:

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

## Local Install

For local use on your Mac, you do not need a DMG, notarization, or public distribution packaging.

Build a local Release app:

```bash
./Scripts/build_local_release.sh
```

Install it into `/Applications`:

```bash
./Scripts/build_local_release.sh --install
```

Build, install, and launch:

```bash
./Scripts/build_local_release.sh --install --open
```

## CLI Launcher

Launch ForgeText from Terminal:

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

If ForgeText is somewhere other than `/Applications`, point the launcher at it:

```bash
FORGETEXT_APP=/path/to/ForgeText.app ./Scripts/forgetext --help
```

## Public GitHub Download Flow

Build a GitHub Release-ready DMG:

```bash
./Scripts/build_release_dmg.sh
```

That writes a versioned DMG to:

```text
dist/ForgeText-1.2-3.dmg
```

Recommended distribution flow:

1. Build the DMG with `./Scripts/build_release_dmg.sh`.
2. Create a GitHub Release such as `V1.2`.
3. Upload the DMG as a release asset.
4. Generate or update the Sparkle appcast.
5. Push `docs/appcast.xml` so GitHub Pages serves the feed.

Notes:

- Use GitHub Releases for downloadable binaries; do not commit generated DMGs to `main`.
- For public distribution, the app and DMG should eventually be Developer ID signed and notarized.
- The updater feed lives at `https://jaysonguglietta.github.io/ForgeText/appcast.xml`.
- ForgeText now includes `Tools > Release Readiness` to check the local release setup from inside the app.

## Project Layout

- `project.yml`: XcodeGen project definition.
- `ForgeText/`: application source.
- `ForgeTextTests/`: unit tests.
- `Scripts/`: helper scripts for icons, local release builds, DMG packaging, the `forgetext` CLI launcher, and utility tasks.
- `docs/`: help, roadmap, update, and UI planning docs.

## Product Docs

- [ForgeText Help](docs/HELP.md): feature guide and common workflows.
- [Roadmap](docs/ROADMAP.md): shipped scope and future priorities.
- [UI Workbench Plan](docs/UI_WORKBENCH_PLAN.md): retro UI direction and workbench principles.
- [Updates](docs/UPDATES.md): GitHub Pages and Sparkle update setup.
