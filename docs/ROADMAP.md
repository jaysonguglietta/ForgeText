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

## Current Strengths

- ForgeText is now credible as a local developer text workbench, not just a raw text editor.
- The app has broad support for system-engineer file types: logs, configs, CSV, JSON, HTTP, shell, SQL, and source code.
- Git, AI, plugins, tasks, diagnostics, test output, and terminal output are all surfaced in native panels.
- The retro UI has enough structure to be a real product direction rather than a novelty skin.

## Next Priorities

- Add parser-backed language intelligence and broader symbol extraction.
- Add direct GitHub PR creation, issue context, review comments, and release drafting.
- Add real shortcut rebinding beyond the current shortcut reference.
- Deepen table tooling: sorting, filtering, frozen columns, typed columns, and export/copy helpers.
- Deepen log tooling: timestamp parsing, saved filters, field extraction, timeline clustering, and multi-file sessions.
- Improve remote editing with richer SSH/SFTP operations and safer credential handling.
- Add schema-aware config support for common infrastructure files.
- Add accessibility and UI regression coverage for the retro shell.
- Add public distribution hardening: Developer ID signing, hardened runtime, notarization, and release automation.

## Longer-Term Bets

- LSP-style language packs while preserving ForgeText's native editing core.
- User-defined plugin bundles for snippet packs, tasks, diagnostics, and formatter/linter integrations.
- Saved investigation dashboards for common ops workflows.
- AI context scopes per workspace, folder, file type, and task.
- Repository dashboards that combine Git status, GitHub PRs, tests, problems, and release readiness.
