# ForgeText Roadmap

ForgeText should aim to be the native macOS editor system engineers trust when they are editing live configs, triaging logs, comparing files, and moving quickly through text-heavy workflows.

## Product pillars

- Trust the file: safe saves, recovery, external-change handling, encoding clarity, and predictable behavior.
- See the structure: give JSON, CSV, logs, and config formats views that surface meaning without hiding the raw text.
- Move fast: keyboard-first commands, quick switching, strong search, and low-latency handling of big operational files.
- Stay native: preserve the feel of a Mac editor instead of turning the app into a browser-shaped IDE.

## 1.0 priorities

- Large-file mode with smarter streaming and tail behavior.
- Structured viewers for JSON, logs, YAML, TOML, env files, and diff-heavy workflows.
- Project search with preview, compare tools, and better workbench navigation.
- Safer writes for protected files, symlinks, and metadata-sensitive system files.
- Packaging, notarization, updates, accessibility, and UI regression coverage.

## System engineer features to add next

- Privileged save flow for protected files under `/etc`, `/Library`, and similar paths.
- Remote SSH/SFTP editing with local UI and remote file operations.
- Compressed-file and archive browsing for `.gz`, `.tar`, and related operational assets.
- Terminal/task integration for running checks and opening the current workspace in shell tools.
- Log views with timestamp parsing, severity filters, field extraction, and follow mode.

## Longer-term bets

- Extension hooks or scripts for user-defined transformations.
- Parser-backed outlines and symbol navigation for more languages.
- Session workspaces and saved dashboards for common ops investigations.
