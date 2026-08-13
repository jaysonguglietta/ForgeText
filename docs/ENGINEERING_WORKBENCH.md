# Engineering Workbench

ForgeText keeps the editor itself quiet and moves deeper engineering workflows into one optional window. Open it from `Tools > Engineering Workbench` or press `Command-Shift-E`.

## Workspace Health

The overview combines local, bounded signals for workspace trust, managed policy, indexing, diagnostics, Git state, tests, language tools, and plugins. The score is a local readiness indicator, not remote telemetry or a security certification.

## Code Intelligence

- Select a symbol in the editor or enter a name to find indexed definitions and references.
- Results are capped and source reads are bounded.
- ForgeText reports trusted installations of SourceKit-LSP, TypeScript Language Server, Pyright, Bash Language Server, and JSON Language Server.
- A user can explicitly start a discovered server through a persistent, supervised JSON-RPC session. ForgeText negotiates capabilities, bounds messages, sanitizes the environment, times out requests, cancels stale work, and shuts the process down with the app.
- Open/change/save/close synchronization, completion, definitions, references, diagnostics, code actions, and rename are connected to the editor when the selected trusted server advertises them. The local bounded index remains the fallback.
- LLDB and Python debug adapters can complete a bounded DAP initialization probe. Launch configurations, breakpoints, variables, and a debugger UI remain future work.

## Review Changes

- Inspect changed files without filling the main editor chrome.
- Compare a file side by side with Git HEAD.
- Review text hunks and stage only explicitly checked hunks.
- Expand file history and repository worktree context on demand.
- Open the full Git Workbench for branches, remotes, stashes, commits, and conflict resolution.

Hunk review is limited to existing text files. Binary patches, renames, file creation, deletion, unsafe paths, and patches over 1 MB use safer existing Git flows instead. Git runs with hooks, external diff, terminal prompts, paging, and the file-system monitor disabled.

## Tests And Coverage

ForgeText discovers XCTest, Pytest, and JavaScript tests from the bounded workspace index without running repository code. Running a selected test requires a trusted workspace and policy approval. Coverage reads existing LCOV reports; refreshing the workbench never launches a coverage command.

## Remote Workspaces

Save a validated SSH connection and absolute remote root, browse a capped SFTP directory listing, reconnect through the direct SSH/SFTP or ForgeText remote-agent boundary, and keep remote files read-only by default. Symlink directory entries are not traversed, reads and output are bounded, and writes use an atomic remote temporary-file replacement. Remote actions continue to require workspace trust and managed-policy approval.

The same section detects `.devcontainer/devcontainer.json` or `.devcontainer.json`. Starting a container is an explicit, confirmed action because lifecycle hooks can execute repository-controlled commands. Configuration reads are bounded, symlink escapes are rejected, and the trusted `devcontainer` CLI is launched without a shell.

## Investigations

Capture the active roots, open local and remote files, selected file, searches, Git branch, and operator notes. Investigation records use ForgeText's protected local persistence. Restoring a record reopens its context but does not run tasks or commands.

## Data Tools

Structured tools remain optional views over the raw document. Delimited tables support inferred or overridden column types, schema mapping, stable multi-column sorting, aggregations, filtering, copy/export, a frozen first column, and lazy row rendering. Logs add timestamp parsing, field extraction, saved filters, timeline clustering, and bounded multi-file sessions. Kubernetes, GitHub Actions, Docker Compose, and Dev Container files receive schema-aware diagnostics. Every structured workflow keeps raw text as the source of truth.

## Controlled AI Changes

An AI response containing a unified diff can become a local change set. The response remains inert until the user approves individual hunks. Before application, ForgeText validates patch size, operation type, paths, existing targets, workspace containment, and `git apply --check`. Applied sets can be reversed through the same checked path.

## Enterprise And Profiles

The Enterprise section summarizes effective capability decisions, declarative plugin boundaries, release readiness, protected storage, and diagnostic support. The decision report combines managed policy, workspace trust, Safe Mode, and relevant local hardening settings. Profile Packs export role-oriented workbench settings without AI keys, trust decisions, chats, or other protected local state.

Signed policy status, canonical policy digest, effective update ring, approved AI profiles, managed plugin catalogs, local fleet checks, and encrypted activity-log export controls appear in the same enterprise workflow. ForgeText verifies these controls locally; MDM assignment and centralized collection remain external responsibilities.

## Performance And Privacy

- Workbench refreshes run expensive discovery off the main thread.
- Editor input, syntax highlighting, structured-view switching, Git refreshes, diagnostics, and persistence have explicit responsiveness budgets and rolling P95 measurements in the Performance HUD.
- Typing uses debounced edit-region highlighting, revision-based cache validation, and background document statistics instead of rescanning the whole document on each keypress.
- Text files up to 32 MB remain editable, with adaptive large-file mode beginning at 2 MB; larger regular files open in a secure chunked reader with bounded windows and capped streaming search.
- File and report reads are bounded.
- No workbench data is sent to a service by default.
- Persistent investigations, test results, remote sessions, and AI change records use protected local storage.
- `Restricted Workspace`, Safe Mode, and managed policy continue to override workbench actions.
