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

## Workbench + Advanced

Open `View > Workbench + Advanced...` or press `Command-,`.

This is now the main control surface for tuning ForgeText on your Mac. It combines visual layout controls with the newer runtime, privacy, file-handling, and safety settings.

Sections:

- `Appearance`: Studio, Retro Classic, Retro Pro, and Minimal Pro styles plus density and editor theme.
- `Focus + Layout`: workbench presets, custom layout restore, focus mode, inspector, breadcrumbs, sidebar, bottom panel, and outline visibility.
- `Advanced Runtime`: `Standard` vs `Performance` mode, automatic performance fallback, live diagnostics, document insights, workspace symbol indexing, and large-repository mode.
- `File Handling`: raw-view-first opens, session restore, autosave behavior, default line endings, autosave delay, and external file polling interval.
- `AI Privacy`: local-model-only mode, review-before-send, likely-secret redaction, and maximum context size.
- `Plugin + Remote Safety`: workspace plugins, task-capable plugins, custom registries, remote read-only mode, remote commands, and remote agent install.
- `Safe Mode`: session-level recovery controls that can suppress external plugins, AI, remote connections, terminal/task execution, and previous-session restore.

Changes in this panel apply immediately.

## Engineering Workbench

Open `Tools > Engineering Workbench` or press `Command-Shift-E` when you need deeper workspace context. The main editor stays focused on the document; the workbench groups lower-frequency workflows into:

- `Workspace Health`: trust, policy, index, diagnostics, Git, tests, language tools, and plugins
- `Code Intelligence`: indexed definitions/references and trusted language-tool readiness
- `Review Changes`: compare-with-HEAD, explicit hunk staging, file history, worktree context, and full Git tools
- `Tests + Coverage`: bounded discovery, targeted runs, and existing LCOV reports
- `Remote Workspaces`: saved, validated SSH workspace sessions
- `Investigations`: protected snapshots of files, searches, roots, branch, and notes
- `Data Tools`: raw-first access to delimited, JSON, log, config, HTTP, and archive tools
- `AI Change Sets`: per-hunk review before an AI diff can change existing files
- `Enterprise`: effective policy and local fleet-readiness checks
- `Profile Packs`: exportable role/workbench settings without keys or trust decisions

See [Engineering Workbench](./ENGINEERING_WORKBENCH.md) for limits and security behavior.

Code Intelligence can explicitly start a trusted language server, synchronize the active document, and use advertised completion, definition, reference, diagnostic, code-action, and rename capabilities. Debug adapters currently support a handshake verification only. Remote Workspaces can browse validated SFTP directories and detect/start a development container after an explicit lifecycle-command warning. These actions require a trusted workspace and policy approval.

## Workspace Trust And Restricted Mode

Open `Workspace > Workspace Center` to review trust for the active roots.

Trust modes:

- `Trusted`: tasks, AI actions, remote commands, and approved plugins are available.
- `Restricted`: editing still works, but automatic Git inspection, external workspace plugins and formatters, executable workspace tasks, AI sends, HTTP execution, and remote command flows stay gated until you explicitly trust the workspace.

ForgeText also treats sync bundles conservatively:

- sync export/import transfers safe appearance and workflow preferences
- trusted workspace decisions stay local
- plugin registries stay local
- workspace sessions stay local
- AI chat history stays local

Sensitive local editor state such as recovery snapshots and AI chat persistence uses protected local storage rather than plain exported settings.

## Managed Policy

ForgeText can run in an unmanaged personal mode or under a local admin-managed policy file.

Open `Workspace > Workspace Center` to review the current policy state. The Managed Policy section shows:

- whether a policy is active
- where it was loaded from
- any load error
- the canonical digest and verified-signature state
- the effective update ring, approved AI profiles, managed plugin catalogs, audit retention, and export decision
- the effective restrictions currently in force

Policy discovery order:

1. forced MDM `ManagedPolicyJSON`
2. `/Library/Application Support/ForgeText/managed-policy.json`
3. `FORGETEXT_MANAGED_POLICY_FILE`
4. the local ForgeText app-data folder

Use `Tools > Reload Managed Policy` after updating the file on disk.

If a discovered policy is malformed, symlinked, oversized, insecurely writable, incorrectly owned, or uses an unsupported version, ForgeText shows the error and denies managed high-risk capabilities by default instead of silently falling back to unmanaged behavior.

See [Managed Policy](./MANAGED_POLICY.md) for the full schema and a ready-to-edit example.

## Portable Mode

Portable mode is intentionally opt-in. For an app-adjacent portable store:

1. Create `ForgeTextData` beside `ForgeText.app`.
2. Create an empty `ForgeTextData/.forgetext-portable` marker.
3. Make the directory private with `chmod 700 ForgeTextData`.

Alternatively, set `FORGETEXT_PORTABLE_DATA_DIR` to an existing private directory. The directory must be owned by the current user, must not be a symlink, and must have no group or other permissions. ForgeText will ignore an unsafe portable directory and use normal Application Support storage.

Sensitive portable state remains encrypted, but its Keychain encryption key is device-bound. Plaintext legacy sensitive-state files are not auto-migrated from portable storage.

## Navigation

### Quick Open

Open Quick Open from `Search > Quick Open...`, the toolbar, or `Command-P`.

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

Managed enterprise activity is also recorded through a serialized background writer in encrypted local storage. Policy controls 1-365 day retention, whether details are retained, and whether a permission-restricted JSONL export is allowed. This is a local support/audit trail, not centralized telemetry or a tamper-proof ledger.

## Diagnostic Bundle Export

Open `Tools > Export Diagnostic Bundle...`.

The exported bundle includes:

- app version and build
- hashed workspace and open-document labels instead of raw local paths
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
- raw local filesystem paths and URL credentials

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

Use these files to make AI behavior project-aware without hardcoding instructions into every chat. ForgeText rejects symlinked rule/prompt files, limits rule files to 64 KB each, caps the combined rules prompt, and limits prompt discovery count so an opened repository cannot force unbounded AI context loading.

Optional `.forgetext/ai-scopes.json` rules can add instructions only when the current file path, extension, and/or AI quick action matches. For example:

```json
{
  "version": 1,
  "scopes": [
    {
      "id": "production-kubernetes",
      "name": "Production Kubernetes review",
      "pathPrefixes": ["deploy/production"],
      "fileExtensions": ["yaml", "yml"],
      "tasks": ["explain", "improve"],
      "instructions": "Call out availability, secret, and rollback risks before suggesting changes."
    }
  ]
}
```

Scope files are bounded, containment checked, decoded as untrusted input, and capped at 100 rules/64 KB of matched instructions. Matching instructions appear as workspace-rules context in the pre-send manifest and remain subject to trust, policy, redaction, and context limits.

## AI Workbench

Open `AI > AI Workbench` or `Tools > AI Context Center > AI Workbench`.

Supported provider profiles:

- OpenAI
- Anthropic
- Google Gemini
- Ollama
- OpenAI-compatible endpoints

API keys stay local in macOS Keychain, use device-bound `WhenUnlocked` accessibility, and are not included in settings transfer bundles. ForgeText caches successful Keychain reads for the running process to avoid repeated authorization prompts.

Setup modes:

- `Bring Your Own Key` for cloud providers such as OpenAI, Anthropic, and Gemini
- `Local Model` for Ollama or OpenAI-compatible local endpoints such as LM Studio

When an admin policy is active, ForgeText can also limit:

- cloud providers vs local models
- allowed provider kinds
- allowed model-name prefixes
- whether selection, current-file, or workspace-rules context is allowed
- exact allowed endpoint hosts

Quick actions:

- Explain Selection
- Improve Selection
- Generate Tests
- Summarize File
- Draft Commit Message

Workspace trust must allow AI actions before the workbench opens.

If `Review before send` is enabled in `Workbench + Advanced`, ForgeText will show the final prepared system prompt and user prompt before any request leaves the app. If `Redact likely secrets before send` is also enabled, ForgeText masks likely keys, bearer tokens, private keys, and common secret assignments before you review or send the prompt.

The review sheet also shows a context manifest with every included source, its character count, and whether redaction or truncation changed the outbound request.

If `Local models only` is enabled, ForgeText limits AI usage to local-model endpoints such as Ollama or OpenAI-compatible local servers like LM Studio.

Cloud-provider credentials are host pinned: OpenAI, Anthropic, and Gemini keys are only sent to their official API host. Use an `OpenAI Compatible` profile for a custom cloud gateway. Local-model profiles must resolve only to private or loopback addresses and do not require an API key.

## Git And GitHub

Open `Source Control > Git Workbench` for local Git actions.

Git features are unavailable while a workspace is restricted. In trusted workspaces, ForgeText disables repository-defined fsmonitor hooks, hooks paths, external diff/text-conversion drivers, pagers, editors, interactive credential prompts, and the `ext` transport for its Git subprocesses.

Local Git features include:

- clone repository
- fetch, pull, push
- stage and unstage files
- stage explicitly selected text hunks
- commit
- create and switch branches
- stash flows
- changed-file lists
- recent graph history
- selected-file history and repository worktree context
- remotes
- compare current file with HEAD
- diff-gutter markers
- current-line blame context
- merge-conflict helpers

Open `Source Control > GitHub Workflow...` or `Tools > GitHub Workflow`.

GitHub Workflow uses the trusted GitHub CLI and your existing `gh` authentication. It can:

- open the repository page
- open a compare page for the current branch
- list up to 50 open pull requests
- create a pull request
- load issue context and workflow/check results
- load paginated pull-request review threads
- open a selected pull request
- post an explicitly confirmed pull-request comment through standard input
- prepare a draft GitHub release

ForgeText does not store a GitHub token. Run `gh auth login` outside ForgeText when authentication is needed. Authentication, SSO enforcement, and API authorization remain GitHub CLI responsibilities.

## Sidebar Workbench

ForgeText now uses a quieter left workbench with four focused panes.

Main panes:

- `Files`: open documents and the workspace tree
- `Search`: focused project search
- `Source Control`: current branch, changed files, and stage/unstage actions
- `Workbench`: a compact health summary and entry points into the Engineering Workbench

Quick Open, Command Palette, tasks, terminal, AI, plugins, setup, and preferences remain available from menus and keyboard shortcuts instead of occupying permanent sidebar space.

When a managed policy is active, blocked actions stay visible where useful, but they are disabled or intercepted with a clear explanation instead of silently failing.

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
- files above the editable limit: chunked read-only text

Use the document header's format toggle to move between the structured view and raw text.

Fresh file opens now begin in raw text view by default. Structured viewers stay available on demand, but ForgeText no longer forces CSV, JSON, log, or HTTP files into their alternate view immediately on open.

Delimited tables support inferred and overridden schemas, stable multi-column sorting, filtering, aggregations, frozen-first-column mode, and visible-row copy/export. Rows render lazily so larger editable datasets do not create every row view up front.

Log Explorer parses common timestamps and key/value fields, supports saved filters and timeline clusters, and can merge a bounded set of files into one multi-file session. Configuration diagnostics understand Kubernetes, GitHub Actions, Docker Compose, and Dev Container conventions without replacing the raw document.

Regular files above the 32 MB editable limit use a secure chunked reader instead of a full-memory preview. Navigation reads bounded windows with `pread`, symlinks/non-regular files are rejected, and search is capped. Chunked mode is intentionally read-only; use a purpose-built streaming tool when a file exceeds its search boundary.

The HTTP runner is available only in a trusted workspace. It accepts HTTP/HTTPS request files, rejects embedded URL credentials and redirects, caps response size, and blocks private or loopback destinations until you confirm the target. Managed policy can disable the runner, require an exact host allowlist, or prohibit private destinations entirely.

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

The HUD also shows the active runtime mode, Safe Mode, rolling P95 operation time, and whether each measured editor operation remains within its responsiveness budget.

## Theme Lab

Open `Tools > Theme Lab`.

Theme Lab controls:

- Workbench Style: Studio, Retro Classic, Retro Pro, or Minimal Pro
- Density: Comfortable, Compact, or Dense
- editor theme
- focus mode
- inspector visibility

The default recommendation is `Studio` for everyday editing, with the retro styles still available as alternate shells.

## Performance Mode And Safe Mode

ForgeText now gives you two different ways to reduce noise or overhead:

- `Performance Mode`: keeps the normal feature set available, but scales back expensive background work so typing latency stays lower in heavier files and repositories.
- `Safe Mode`: reduces the trust surface of the whole session and is better for support, recovery, or cautious inspection workflows.

Typical `Performance Mode` changes:

- slower or disabled live diagnostics
- slower or disabled document insight refresh
- calmer workspace-symbol and Git-side refresh behavior
- gentler large-repository behavior

Typical `Safe Mode` changes:

- optional clean startup without restoring the last session
- optional blocking of external plugins
- optional blocking of AI
- optional blocking of remote connections
- blocking of workspace tasks and embedded terminal commands

ForgeText surfaces both states in the status bar when active.

## Keyboard Shortcuts

Open `Tools > Keyboard Shortcuts` to rebind supported commands. ForgeText validates key/modifier combinations, reports conflicts before saving, persists custom bindings, and can reset individual actions or the full map to defaults.

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
- `Command-,`: Workbench + Advanced

The same panel shows the complete in-app reference.

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
DEVELOPER_ID_APPLICATION="Developer ID Application: Example Corp (TEAMID)" \
NOTARYTOOL_PROFILE="forgetext-notary" \
./Scripts/build_release_dmg.sh
```

Then:

1. Confirm signature, hardened runtime, notarization, stapling, Gatekeeper assessment, and the generated SHA-256 checksum all succeeded.
2. Create a GitHub Release.
3. Upload the DMG and checksum.
4. Generate or update the Sparkle appcast.
5. Push `docs/appcast.xml`.
6. Use `Check for Updates...` to verify the feed.

See [UPDATES.md](UPDATES.md) for the detailed release flow.
