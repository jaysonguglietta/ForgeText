# ForgeText Roadmap

ForgeText should be the native macOS editor system engineers and developers trust when editing live configs, triaging logs, comparing files, navigating repositories, running checks, and using AI without losing control of the underlying text.

## Product Pillars

- Trust the file: safe saves, recovery, external-change handling, encoding clarity, and predictable behavior.
- See the structure: give JSON, CSV, logs, HTTP, archives, and config formats useful views without hiding raw text.
- Move fast: keyboard-first commands, Quick Open, command palette modes, project search, symbol search, and low-latency workbench panels.
- Stay native: preserve Mac editing behavior instead of turning the app into a browser-shaped IDE.
- Keep context local-first: workspace index, Git status, AI rules, release checks, and diagnostics should be useful without cloud dependencies.

## Shipped In 1.0

ForgeText 1.0 established the core workbench:

- Native AppKit-backed editor surface with multi-document tabs and document sidebar.
- Encoding, BOM, and line-ending preservation.
- Autosave recovery, session restore, crash recovery, and external-change handling.
- Find/replace, go-to-line, command palette, and project search.
- Outline rail, breadcrumbs, split-pane workbench modes, and status metrics.
- Structured views for CSV, JSON, logs, HTTP request files, archives, and config-oriented formats.
- Large-file previews, binary hex fallback, archive browsing, and follow-mode support.
- Local install workflow for `/Applications`.
- Retro-web shell direction layered on top of the native editor core.
- Plugin layer with snippets, task runner, diagnostics, formatting, and Git-aware IDE features.
- Workspace explorer, embedded terminal, remote grep/command workflows, and external plugin manifests.
- Inline diagnostics, diff-gutter markers, Git blame context, and secret-aware warnings.
- Provider-neutral AI workbench with workspace rules, provider profiles, quick actions, and reusable sessions.

## Shipped In 1.1

ForgeText 1.1 adds the productivity and production-readiness layer:

- Quick Open for indexed workspace files and symbols.
- Command Palette 2.0 with `> commands`, `@ files`, and `# symbols`.
- Workspace Indexer for file, symbol, TODO/FIXME/HACK, and warning summaries.
- Activity Center for local editor and workspace event history.
- First-Run Setup checklist for onboarding a workspace.
- AI Context Center for workspace rules and reusable prompt files.
- GitHub Workflow panel for detected GitHub remotes and compare-page launch.
- Release Readiness panel for Sparkle, appcast, DMG, docs, and version checks.
- Performance HUD for local app and workspace snapshot metrics.
- Theme Lab for retro chrome, density, editor theme, focus mode, and inspector controls.
- Safe diagnostic bundle export for support without document contents or AI API keys.

## Shipped In 1.2.1

ForgeText 1.2.1 hardens the trust and local-data model:

- Restricted workspaces now block external workspace plugins and executable workspace tasks by default.
- Workspace trust is resolved against bookmarked/canonical locations so retargeted symlinks do not silently inherit trust.
- Sync bundle transfer now keeps trusted workspaces, plugin registries, workspace sessions, and AI chat history local.
- Recovery snapshots, session state, and AI conversations now use protected local persistence.
- Gemini requests no longer place API keys in the URL.
- Gzip handling now uses bounded decompression and safe preview fallback for oversized content.

## Current Main-Branch Workbench Refresh

- `Studio` workbench style becomes the default for daily use, while retro presets remain available.
- The sidebar is reduced to four focused panes: Files, Search, Source Control, and Workbench.
- Source control moves closer to the main editing flow with a dedicated sidebar pane.
- Quick Open and Command Palette become tighter overlays instead of larger dashboard-style panels.
- Persistent `Quiet UI`, `Balanced`, and `Full Retro` workbench presets preserve custom layout state.
- A first-run chooser helps new installs land on the right shell immediately.
- Shared chrome and backdrop rendering are lighter so the shell feels calmer and more responsive.

## Current Main-Branch Runtime And Enterprise Controls

- `Workbench + Advanced` replaces the older appearance-only tuning flow with one control surface for runtime, file handling, AI privacy, plugin/remote safety, and safe-mode behavior.
- `Performance Mode` becomes a first-class runtime choice for heavier files and repositories.
- Raw-view-first opens become the safer and calmer default even for structured file types.
- AI can now be limited to local models, reviewed before send, redacted for likely secrets, and capped with a stricter context budget.
- Local Safe Mode can suppress external plugins, AI, remote connections, and prior-session restore for recovery or support workflows.
- Workspace profiles now carry advanced behavior settings so teams can reuse more than just visual preferences.

## Current Main-Branch Engineering Workbench

- Workspace Health combines local trust, policy, index, diagnostic, Git, test, language-tool, and plugin signals.
- Indexed definitions/references and trusted language-tool discovery establish a safe language-intelligence foundation.
- Git review adds side-by-side comparison, selected-hunk staging, file history, worktree context, and existing conflict resolution.
- XCTest, Pytest, and JavaScript discovery plus targeted execution and LCOV ingestion create a native test foundation.
- Saved remote sessions and protected investigation records make operational contexts resumable.
- Typed CSV columns, filter, sort, copy/export, and frozen-first-column controls deepen structured data work.
- AI unified diffs become inert, reviewable change sets with per-hunk approval and checked application.
- Forced MDM policy, local fleet checks, and Profile Packs strengthen managed rollout and team configuration.
- Trusted language servers now have a bounded persistent JSON-RPC initialization lifecycle, while debug adapters support an explicit DAP capability probe.
- GitHub review can list open pull requests and post confirmed comments through existing `gh` authentication without storing a token.
- Development-container configuration is inspected safely and started only after trust, policy, and lifecycle-command confirmation.
- AI review exposes an exact context-source manifest before send.

## Current Main-Branch Performance Pass

- Incremental, debounced highlighting replaces whole-document highlighting on every keystroke.
- Document metrics, diagnostics, and outline/structured insights use revisioned background snapshots rather than main-thread full-text validation.
- Rolling P95 performance metrics expose responsiveness-budget regressions locally.
- Adaptive large-file editing now extends to 32 MB, with reduced processing from 2 MB and bounded previews above the edit limit.

## Current Main-Branch Security Hardening Pass

- Subprocess execution now has bounded input/output, timeouts, concurrent pipe draining, and exact trusted tool resolution.
- Restricted workspaces suppress automatic Git execution; trusted Git inspection disables repository hooks, fsmonitor, external diff/text conversion, editors, pagers, prompts, and ext transports.
- AI, HTTP, update, and plugin registry traffic now shares exact-host, private-address, redirect, timeout, and response-size controls.
- Managed policy validates ownership, permissions, file type, size, and version, and fails closed on invalid policy.
- External plugins now carry canonical SHA-256 provenance and optional verified Ed25519 signatures enforceable by policy.
- Sensitive state and AI keys use device-bound Keychain protection; portable storage is explicit and permission checked; diagnostics redact paths.
- Sparkle is upgraded to 2.9.4, hardened runtime is enabled, and public release tooling enforces Developer ID signing, notarization, stapling, Gatekeeper, and checksums.
- Security CI adds pinned GitHub Actions, Swift CodeQL, dependency review, and Dependabot.

## Current Strengths

- ForgeText is now credible as a local developer text workbench, not just a raw text editor.
- The app has broad support for system-engineer file types: logs, configs, CSV, JSON, HTTP, shell, SQL, and source code.
- Git, AI, plugins, tasks, diagnostics, test output, and terminal output are all surfaced in native panels.
- The workspace trust model is materially stronger than the original 1.0/1.1 behavior.
- ForgeText now has a stronger default UI direction: Studio-first for production work, retro as an optional expression layer.
- ForgeText now has the start of a real enterprise control plane through managed local policy enforcement for AI, plugins, remote flows, updates, and support export.

## Completed Roadmap Batch

The former 1.3, 1.4, and app-side 2.0 roadmap items are now implemented on the current main-branch worktree:

- The Studio shell has stable accessibility identifiers and a dedicated macOS UI smoke-test target. The normal app scheme remains fast, while shell automation runs explicitly through `ForgeTextUITests`.
- Files above the 32 MB editable limit open in a secure chunked reader. It uses bounded `pread` windows, rejects symlinks and non-regular files, and performs capped streaming search without loading the entire file.
- Delimited data supports schema overrides, stable multi-column sort, aggregations, frozen columns, visible-row export, and lazy row rendering.
- Logs support parsed timestamps, field extraction, saved filters, timeline clusters, and bounded multi-file sessions.
- Infrastructure configuration diagnostics understand Kubernetes, GitHub Actions, Docker Compose, and Dev Container schemas while preserving raw-first editing.
- The supervised LSP runtime now handles document open/change/save/close synchronization, cancellation, completion, definitions, references, diagnostics, code actions, and rename with bounded JSON-RPC messages and controlled shutdown.
- GitHub Workflow now covers pull-request creation, issue context, checks, paginated review threads, confirmed comments, and draft release creation through existing `gh` authentication.
- Shortcuts are persistently rebindable with conflict detection and reset-to-default behavior.
- Remote workflows add validated SFTP directory browsing, bounded reads, atomic writes, strict host/reference parsing, saved sessions, remote-agent operations, and explicit local-versus-remote labels.
- Managed policy supports verified Ed25519 policy artifacts, trusted administrator keys, approved AI provider packs, managed private plugin catalogs, update rings/feed controls, policy digests, and fail-closed validation.
- Enterprise activity events are serialized off the main thread, encrypted at rest, retained for a policy-bounded period, privacy-redacted, capped, and exportable as permission-restricted JSONL when policy allows.
- Release builds generate provenance metadata alongside notarization, signature, Gatekeeper, checksum, and dependency/security-CI gates.
- Declarative plugin language packs can safely map filename/extension aliases onto ForgeText's existing native language modes without loading executable code into the app process.
- Workspace AI scopes in `.forgetext/ai-scopes.json` can apply bounded instructions by folder, file type, and quick-action task; the final context remains visible in the pre-send manifest and subject to trust, policy, redaction, and size limits.
- The Engineering Workbench repository overview combines Git, GitHub, tests, problems, release readiness, policy, and saved investigation context without adding permanent editor chrome.

## Remaining Product Boundary

The following items are intentionally not presented as local-editor features because they require a separately operated service and organizational controls:

- tenant identity, SSO, server-side roles, and multi-tenant authorization
- centralized policy assignment, audit ingestion, fleet dashboards, and remote attestation
- hosted collaborative editing, shared cloud investigations, and offline review queues
- organization-wide certificate issuance, signing-key rotation, artifact promotion, and revocation services
- a hosted extension marketplace or remote execution plane

ForgeText continues to integrate with MDM, endpoint security, artifact signing, GitHub CLI, and organization-owned services rather than pretending those control planes exist inside one desktop process.

## Next Validation Cycle

- Establish reproducible performance fixtures for multi-gigabyte logs, large delimited datasets, and monorepo indexing.
- Expand UI automation from the shell smoke test to tab lifecycle, raw/structured switching, Git hunk review, and keyboard-only workflows.
- Add full debugger launch configurations, breakpoints, variables, watches, and debug-console UX on top of the existing bounded DAP probe.
- Validate managed policy, private catalogs, update rings, and audit export with representative MDM and air-gapped deployment environments.
- Continue accessibility review across every optional workbench and retro preset, including VoiceOver announcements and high-contrast behavior.
