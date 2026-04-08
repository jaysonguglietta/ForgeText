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

## 1.0 priorities still open

- Large-file mode with smarter streaming and tail behavior.
- Richer structured viewers for diff-heavy workflows, archive contents, and schema-aware configs.
- Project search with preview, compare tools, and stronger multi-pane workbench navigation.
- Safer writes for protected files, symlinks, and metadata-sensitive system files.
- Packaging, notarization, updates, accessibility, and UI regression coverage.

## System engineer features to add next

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
- Plugin-manager polish, richer task output handling, and deeper diagnostics panels.

## Longer-term bets

- Plugin manifests for user-defined snippet packs, tasks, and formatter/linter integrations.
- Parser-backed outlines, real LSP-style language packs, and symbol navigation for more languages.
- Session workspaces and saved dashboards for common ops investigations.
