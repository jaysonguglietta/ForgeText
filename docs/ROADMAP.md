# ForgeText Roadmap

ForgeText should aim to be the native macOS editor system engineers trust when they are editing live configs, triaging logs, comparing files, and moving quickly through text-heavy workflows.

## Product pillars

- Trust the file: safe saves, recovery, external-change handling, encoding clarity, and predictable behavior.
- See the structure: give JSON, CSV, logs, and config formats views that surface meaning without hiding the raw text.
- Move fast: keyboard-first commands, quick switching, strong search, and low-latency handling of big operational files.
- Stay native: preserve the feel of a Mac editor instead of turning the app into a browser-shaped IDE.

## Shipped already

- Native AppKit-backed editor surface with multi-document tabs and document sidebar.
- Encoding, BOM, and line-ending preservation.
- Autosave recovery, session restore, crash recovery, and external-change handling.
- Find/replace, go-to-line, command palette, and project search.
- Outline rail, breadcrumbs, split-pane workbench modes, and status metrics.
- Structured views for CSV, JSON, logs, and config-oriented workflows.
- Large-file previews, binary hex fallback, archive browsing, and follow-mode support.
- Local install workflow for `/Applications`.
- A full retro-web shell direction layered on top of the native editor core.
- A built-in plugin layer with snippet, task-runner, diagnostics, formatting, and Git-aware IDE features.
- Workspace explorer, embedded terminal, HTTP request runner, remote grep/command workflows, and external plugin manifests.
- Inline diagnostics, diff-gutter markers, Git blame context, and secret-aware warnings for risky file contents.

## ForgeText 1.0 shipped scope

ForgeText 1.0 now includes:

- A native editor workbench with tabs, split panes, outline, breadcrumbs, command palette, and project search.
- Structured viewing for CSV, JSON, logs, HTTP request files, archives, and config-oriented formats.
- Workspace explorer, embedded terminal, task runner, problems panel, and test explorer.
- Local Git workflows including clone, fetch, pull, push, commit, branch creation, stash flows, compare, blame context, and diff markers.
- A provider-neutral AI workbench with reusable sessions, workspace rules, provider profiles, and quick editor actions.
- Plugin surfaces for snippets, diagnostics, formatting hooks, and external plugin manifests.
- Recovery-oriented file handling for encodings, line endings, large files, binary fallbacks, crash recovery, and session restore.

## Post-1.0 priorities

- Parser-backed language intelligence, symbol indexing, and deeper formatter/linter integrations.
- GitHub-native workflows like pull requests, issue context, and richer repo collaboration surfaces.
- Safer privileged save paths, remote editing depth, and stronger metadata-preserving write behavior.
- More advanced structured data tooling for tables, logs, config schemas, and diff-heavy reviews.
- Packaging, notarization, auto-update, accessibility, telemetry, and UI regression coverage.

## System engineer features to deepen next

- Privileged save flow for protected files under `/etc`, `/Library`, and similar paths.
- Remote SSH/SFTP editing with richer local UI, remote file operations, and safer credential handling.
- Compressed-file and archive browsing for `.gz`, `.tar`, and related operational assets.
- Terminal/task integration for running checks and opening the current workspace in shell tools.
- Log views with timestamp parsing, severity filters, field extraction, and follow mode.

## UX and workbench next pass

- Richer CSV and structured-data interactions: sort, filter, freeze columns, and copy helpers.
- Better diff and compare workflows for system config reviews.
- Saved searches, pinned documents, and more session-oriented workbench behavior.
- More file-aware empty states and better disclosure around read-only and preview modes.
- Plugin-manager polish, richer task output handling, deeper diagnostics panels, and tighter AI/Git workbench ergonomics.

## Longer-term bets

- Plugin manifests for user-defined snippet packs, tasks, and formatter/linter integrations.
- Parser-backed outlines, real LSP-style language packs, and symbol navigation for more languages.
- Session workspaces and saved dashboards for common ops investigations.
