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
- The sidebar shifts to an activity-rail + pane model so navigation feels more like a real editor workbench.
- Source control moves closer to the main editing flow with a dedicated sidebar pane.
- Quick Open and Command Palette become tighter overlays instead of larger dashboard-style panels.
- Persistent `Quiet UI`, `Balanced`, and `Full Retro` workbench presets preserve custom layout state.
- A first-run chooser helps new installs land on the right shell immediately.
- Shared chrome and backdrop rendering are lighter so the shell feels calmer and more responsive.

## Current Strengths

- ForgeText is now credible as a local developer text workbench, not just a raw text editor.
- The app has broad support for system-engineer file types: logs, configs, CSV, JSON, HTTP, shell, SQL, and source code.
- Git, AI, plugins, tasks, diagnostics, test output, and terminal output are all surfaced in native panels.
- The workspace trust model is materially stronger than the original 1.0/1.1 behavior.
- ForgeText now has a stronger default UI direction: Studio-first for production work, retro as an optional expression layer.

## Next Priorities

- Add parser-backed language intelligence and broader symbol extraction.
- Add direct GitHub PR creation, issue context, review comments, and release drafting.
- Add real shortcut rebinding beyond the current shortcut reference.
- Deepen table tooling: sorting, filtering, frozen columns, typed columns, and export/copy helpers.
- Deepen log tooling: timestamp parsing, saved filters, field extraction, timeline clustering, and multi-file sessions.
- Improve remote editing with richer SSH/SFTP operations and safer credential handling.
- Add schema-aware config support for common infrastructure files.
- Add accessibility and UI regression coverage for the Studio shell and the remaining retro variants.
- Add public distribution hardening: Developer ID signing, hardened runtime, notarization, and release automation.

## Longer-Term Bets

- LSP-style language packs while preserving ForgeText's native editing core.
- User-defined plugin bundles for snippet packs, tasks, diagnostics, and formatter/linter integrations.
- Saved investigation dashboards for common ops workflows.
- AI context scopes per workspace, folder, file type, and task.
- Repository dashboards that combine Git status, GitHub PRs, tests, problems, and release readiness.
