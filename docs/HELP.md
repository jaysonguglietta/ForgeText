# ForgeText Help

This guide covers the main ForgeText 1.2.1 workflows, including the productivity panels, the newer trust and data-protection guardrails, and the current Studio-first workbench layout.

## First Run

On a brand-new install, ForgeText opens a small workbench chooser first so you can start in `Quiet UI`, `Balanced`, or `Full Retro`.

Open `Tools > First-Run Setup` when setting up a new Mac or workspace. It walks through:

- choosing a workspace
- building the workspace index
- checking AI context files
- reviewing plugins
- checking update/release readiness
- tuning the workbench style

The checklist is safe to run repeatedly. It does not change files by itself unless you click into a tool and make a change.

Workbench presets stay available later from the document header and `View` menu, so you can switch shells without losing your custom layout state.

## Workspace Trust And Restricted Mode

Open `Workspace > Workspace Center` to review trust for the active roots.

Trust modes:

- `Trusted`: tasks, AI actions, remote commands, and approved plugins are available.
- `Restricted`: editing still works, but external workspace plugins, executable workspace tasks, AI sends, and remote command flows stay gated until you explicitly trust the workspace.

ForgeText also treats sync bundles conservatively:

- sync export/import transfers safe appearance and workflow preferences
- trusted workspace decisions stay local
- plugin registries stay local
- workspace sessions stay local
- AI chat history stays local

Sensitive local editor state such as recovery snapshots and AI chat persistence uses protected local storage rather than plain exported settings.

## Navigation

### Quick Open

Open Quick Open from `Search > Quick Open...`, the sidebar Navigate pane, the toolbar, or `Command-P`.

Quick Open uses the workspace index to jump to:

- indexed workspace files
- open documents
- symbols discovered from supported file types

If results look stale, click `Reindex` or run `Tools > Refresh Workspace Index`.

### Command Palette

Open the command palette from `Search > Command Palette...` or `Command-Shift-P`.

Search modes:

- `All`: searches commands, files, symbols, tasks, plugins, settings, themes, languages, and recent files.
- `Commands`: searches actions and settings.
- `Files`: searches open documents, recent files, and indexed files.
- `Symbols`: searches indexed symbols.

Prefix shortcuts:

- `>` searches commands, actions, settings, tasks, plugins, themes, and language choices.
- `@` searches files.
- `#` searches symbols.

Examples:

```text
> release
@ README
# AppState
```

## Workspace Index

The workspace index powers Quick Open, command-palette file mode, command-palette symbol mode, and summary counts in the Activity Center.

The index tracks:

- text files under active workspace roots
- file language
- relative path
- line count
- symbol count
- TODO/FIXME/HACK markers
- likely secret/config warnings

The index intentionally skips common heavy folders like `.git`, `node_modules`, `.build`, `DerivedData`, `dist`, and `vendor`.

## Activity Center

Open `Tools > Activity Center` to review recent local activity.

Activity Center shows:

- opened and saved files
- workspace indexing events
- release-readiness checks
- diagnostic bundle exports
- workspace index totals

Use `Export Diagnostics` from this panel when you need a safe support bundle.

## Diagnostic Bundle Export

Open `Tools > Export Diagnostic Bundle...`.

The exported bundle includes:

- app version and build
- workspace root paths
- open document names and paths
- settings names such as theme, chrome style, density, focus mode, and inspector state
- workspace index summaries
- release-readiness summary
- recent activity log
- Git summary when available

The bundle intentionally excludes:

- document contents
- AI provider API keys
- full AI chat contents
- private Sparkle signing keys

## AI Context

Open `Tools > AI Context Center`.

ForgeText loads workspace rules from:

- `.forgetext/rules.md`
- `.forgetext/ai-rules.md`
- `.github/copilot-instructions.md`
- `AGENTS.md`
- `CLAUDE.md`
- `GEMINI.md`
- `CODEX.md`
- `.cursorrules`

ForgeText loads reusable prompts from:

- `.forgetext/prompts/*.md`
- `.forgetext/prompts/*.txt`
- `.forgetext/prompts/*.prompt`

Use these files to make AI behavior project-aware without hardcoding instructions into every chat.

## AI Workbench

Open `AI > AI Workbench` or `Tools > AI Context Center > AI Workbench`.

Supported provider profiles:

- OpenAI
- Anthropic
- Google Gemini
- Ollama
- OpenAI-compatible endpoints

API keys stay local and are not included in settings transfer bundles.

Quick actions:

- Explain Selection
- Improve Selection
- Generate Tests
- Summarize File
- Draft Commit Message

Workspace trust must allow AI actions before the workbench opens.

## Git And GitHub

Open `Source Control > Git Workbench` for local Git actions.

Local Git features include:

- clone repository
- fetch, pull, push
- stage and unstage files
- commit
- create and switch branches
- stash flows
- changed-file lists
- recent graph history
- remotes
- compare current file with HEAD
- diff-gutter markers
- current-line blame context
- merge-conflict helpers

Open `Source Control > GitHub Workflow...` or `Tools > GitHub Workflow`.

GitHub Workflow detects GitHub remotes and can open:

- the repository page
- a compare page for the current branch

This is a local-first PR preparation panel. It does not yet create PRs directly from ForgeText.

## Sidebar Workbench

ForgeText now uses a more editor-like left workbench with an activity rail and focused panes.

Main panes:

- `Explorer`: open documents, workspace tree, and recent files
- `Source Control`: current branch, changed files, and stage/unstage actions
- `Workspace`: roots, clone/open flows, sessions, and remote entry points
- `Navigate`: Quick Open, Command Palette, search, go-to-line, keyboard shortcuts, and activity
- `Tools` and `Extensions`: Git, AI, terminal, problems, tests, plugins, tasks, snippets, setup, and appearance

## Structured Views

ForgeText recognizes common file types and can switch between raw editing and structured inspection.

Structured views:

- CSV and delimited files: table view
- JSON: tree view
- logs: log explorer
- YAML/TOML/INI/env/config: config inspector
- `.http` and `.rest`: HTTP request runner
- archives: archive browser
- binary or undecodable files: hex preview

Use the document header's format toggle to move between the structured view and raw text.

## Release Readiness

Open `Tools > Release Readiness`.

The panel checks:

- app version and build metadata
- Sparkle `SUFeedURL`
- Sparkle `SUPublicEDKey`
- `Scripts/build_release_dmg.sh`
- `docs/appcast.xml`
- `docs/UPDATES.md`
- DMG files in `dist/`

Use it before publishing a public GitHub Release or updating the appcast.

## Performance HUD

Open `Tools > Performance HUD`.

The HUD shows:

- open document count
- dirty document count
- indexed file count
- indexed symbol count
- workspace root count
- enabled plugin count
- detected task count
- system memory and uptime

This is a lightweight snapshot for debugging the local app. It is not telemetry.

## Theme Lab

Open `Tools > Theme Lab`.

Theme Lab controls:

- Workbench Style: Studio, Retro Classic, Retro Pro, or Minimal Pro
- Density: Comfortable, Compact, or Dense
- editor theme
- focus mode
- inspector visibility

The default recommendation is `Studio` for everyday editing, with the retro styles still available as alternate shells.

## Keyboard Shortcuts

Core shortcuts:

- `Command-N`: New
- `Command-O`: Open
- `Command-S`: Save
- `Command-Shift-S`: Save As
- `Command-W`: Close
- `Command-F`: Find and Replace
- `Command-Shift-F`: Search in Folder
- `Command-P`: Quick Open
- `Command-Shift-P`: Command Palette
- `Command-L`: Go to Line
- `Command-Shift-U`: Focus Mode
- `Command-,`: Appearance Preferences

Open `Tools > Keyboard Shortcuts` for the full in-app reference.

## Local Install

Install a local Release build:

```bash
./Scripts/build_local_release.sh --install
```

Build, install, and launch:

```bash
./Scripts/build_local_release.sh --install --open
```

The installed app lives at:

```text
/Applications/ForgeText.app
```

## Public Release

Build a DMG:

```bash
./Scripts/build_release_dmg.sh
```

Then:

1. Create a GitHub Release.
2. Upload the DMG.
3. Generate or update the Sparkle appcast.
4. Push `docs/appcast.xml`.
5. Use `Check for Updates...` to verify the feed.

See [UPDATES.md](UPDATES.md) for the detailed release flow.
