# Enterprise Editor Platform

This document describes the current enterprise-editor architecture on `main`, the trust boundaries around it, and the remaining product boundary. ForgeText is a native macOS editor, not a hosted fleet service.

## Editing And Reliability

- `NSTextView` remains the authoritative editing surface, with native selection, input, undo, and accessibility behavior.
- Keystrokes do not synchronously re-highlight or remeasure the entire document. Highlighting is debounced to an edit-centered line range, and metrics, diagnostics, and document insights run against revisioned background snapshots.
- The Performance HUD records rolling P95 latency for input, highlighting, structured views, Git, diagnostics, insights, and persistence against explicit responsiveness budgets.
- Recovery snapshots are written before autosave attempts. Local saves use same-directory replacement, and successful saves remove the recovery snapshot.
- Files up to 32 MB are editable. Adaptive large-file mode begins at 2 MB and disables expensive decoration/highlighting paths. Larger regular files use a secure chunked read-only surface with bounded `pread` windows and capped streaming search instead of a full-memory decode.

## Language And Debug Protocols

- Language servers are discovered only from trusted absolute tool locations. Starting one is explicit and requires workspace trust and policy approval.
- The runtime uses Content-Length JSON-RPC framing, 16 KB header and 8 MB message limits, bounded standard error, sanitized environment variables, request timeouts, and controlled shutdown.
- The LSP integration performs initialization and capability negotiation, then synchronizes document open/change/save/close events. It exposes bounded completion, definitions, references, diagnostics, code actions, and rename operations with request cancellation and supervised termination.
- ForgeText continues to use its bounded local index as a fallback when a language server is unavailable, untrusted, blocked by policy, times out, or does not advertise the requested capability.
- LLDB and Python debug adapters support a bounded DAP initialization/disconnect probe. ForgeText does not yet provide launch configurations, breakpoint control, variables, watches, or a debug console.

## Team Workflow

- GitHub integration uses the trusted `gh` executable and its existing authentication. ForgeText does not collect or persist a GitHub token.
- The current panel lists open pull requests, issues, checks, and paginated review threads; creates pull requests; opens GitHub pages; posts explicitly confirmed comments; and prepares draft releases. Bodies are delivered over standard input or bounded JSON rather than interpolated into a shell command.
- ForgeText relies on `gh` for authentication, organization SSO enforcement, and API transport. It does not persist a GitHub token or provide a server-side offline review queue.

## Development Containers

- ForgeText detects bounded, regular `.devcontainer/devcontainer.json` and `.devcontainer.json` files contained by the active workspace.
- JSON-with-comments and trailing commas are normalized without modifying string values.
- Starting a container requires workspace trust, managed-policy approval, an explicit user confirmation, and a trusted `devcontainer` CLI path.
- Lifecycle hooks are called out before startup because they can execute repository-controlled commands. ForgeText currently starts the environment but does not reopen the editor inside it or broker an isolated file/terminal channel.

## AI Governance

- Each outbound request can show a pre-send manifest listing instructions, user prompt, selection, current document, and workspace rules with source character counts.
- The manifest reports whether likely-secret redaction or context truncation changed the prepared request.
- Cloud providers use Bring Your Own Key with Keychain-backed credentials. Local Ollama or OpenAI-compatible endpoints can run without a key.
- Workspace trust, Safe Mode, local-model-only settings, exact endpoint controls, and managed context policy all apply before send.
- `.forgetext/ai-scopes.json` can add bounded workspace instructions by path prefix, extension, and quick-action task. Scope files are containment checked, size capped, decoded as untrusted input, and represented in the final workspace-rules context manifest.

## Extension Boundary

- External extensions are declarative data manifests. ForgeText does not load third-party dynamic libraries or arbitrary extension binaries into the app process.
- Declarative language packs may map safe filename/extension aliases onto an existing ForgeText language mode. They do not add parsers or execute code, and external packs remain blocked in restricted workspaces.
- Task capabilities still cross an execution boundary and therefore require workspace trust, executable allowlisting, bounded subprocess execution, and policy approval.
- If native executable extensions are introduced later, they must use a separately signed XPC service with explicit entitlements, message schemas, timeouts, crash isolation, and organization-controlled provenance. They should not be added to the current in-process manifest model.

## Effective Policy

`Engineering Workbench > Enterprise` resolves one local capability report from:

1. managed policy
2. workspace trust
3. Safe Mode
4. relevant local AI, plugin, task, and remote hardening settings

Invalid managed policy fails closed for high-risk capabilities while leaving local editing available.

Signed policy artifacts use Ed25519 signatures over canonical JSON. Administrator trust roots come from forced preferences or the deployment environment; configured trust roots make signatures mandatory. Verified policy can also select update rings and exact HTTPS feeds, supply approved AI profiles, and define signed managed plugin catalogs. Unsigned local policy may restrict updates but cannot redirect the updater.

Enterprise activity events are queued off the main thread, privacy-redacted, encrypted at rest, capped, retained for 1-365 days, and exportable as mode-`0600` JSONL only when policy permits. The log is a local support/audit aid, not a tamper-proof centralized ledger.

## Operational Modes And UI

The workbench offers Editing, Review, Incident, and Data modes. These switch the current workflow and optional panes without overwriting the user's appearance settings. The main shell remains document-first: Files, Search, Source Control, and Workbench are the only permanent sidebar destinations, while advanced operations live in the optional Engineering Workbench.

## Explicit Enterprise Boundary

ForgeText does not currently provide tenant accounts, server-side authorization, centralized telemetry, collaborative live editing, a fleet dashboard, remote attestation, organization-wide key rotation, or a hosted plugin marketplace. It verifies local signed artifacts and emits local release provenance, but issuance, assignment, revocation, collection, and fleet reporting remain responsibilities of an external control plane. Local UI should not imply those hosted controls exist.
