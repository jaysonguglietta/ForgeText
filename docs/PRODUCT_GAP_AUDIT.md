# ForgeText Product Gap Audit

This audit compares the current app with a serious enterprise developer editor: fast local editing, deep but optional engineering workflows, enforceable security boundaries, and supportable team deployment.

## Current Position

ForgeText is now a credible native engineering workbench:

- AppKit editing, raw-first files, recovery, encoding, line-ending, and external-change reliability
- a calm four-pane shell with deeper tools moved out of the typing path
- workspace trust, Safe Mode, forced MDM/file policy, protected persistence, and endpoint-pinned AI credentials
- bounded processes, files, archives, network responses, Git inspection, and workspace indexing
- signed plugin provenance, exact allowlists, security CI, hardened runtime, and notarized release gates
- local workspace health, indexed navigation, reviewable Git hunks, targeted tests, coverage, remote sessions, investigations, data tools, and controlled AI change sets

## Closed Product Gaps

The current roadmap batch closes the previously identified app-side gaps:

- LSP sessions synchronize documents and expose bounded completion, navigation, diagnostics, rename, and code-action operations with cancellation and supervised process lifecycle.
- GitHub Workflow supports pull-request creation, issues, checks, review threads, confirmed comments, and draft releases through the trusted GitHub CLI.
- Remote editing now includes saved sessions, strict SSH references, SFTP browsing, bounded operations, atomic saves, retries, and optional remote-agent support. It remains intentionally non-transparent about where commands execute.
- Enterprise controls now accept signed policy artifacts, update rings, approved AI profiles, managed signed catalogs, encrypted local audit events, retention/export policy, and release provenance output.
- Large structured datasets use lazy rows and multi-sort/aggregation controls, while files above the editable boundary use a chunked reader and capped streaming search.

## Remaining Gaps

### 1. Hosted Enterprise Control Plane

ForgeText does not provide tenant accounts, SSO, centralized assignment, fleet telemetry, remote attestation, or server-side audit retention. Those require a separately threat-modeled service and organization-owned operations.

### 2. Full Debugger Experience

The DAP boundary is probed safely, but launch configurations, breakpoint state, stepping, variables, watches, and a debug console are not yet a complete user workflow.

### 3. Remote Compute Orchestration

ForgeText supports bounded remote files, search, commands, and agent operations. Persistent interactive terminals, port forwarding, remote test distribution, and reconnectable process supervision need a larger remote-runtime design and should not be simulated with unsafe shell shortcuts.

### 4. Proven Scale Baselines

The implementation is bounded and instrumented, but enterprise claims still require reproducible fixtures, latency budgets, soak testing, and memory profiles across representative monorepos, multi-gigabyte logs, and large delimited datasets.

### 5. Breadth Of Accessibility Validation

The Studio shell has stable accessibility identifiers and a macOS UI smoke target. Full VoiceOver, high-contrast, keyboard-only, localization, and every-preset regression coverage remains an ongoing validation program.

## Product Principle

ForgeText should grow in depth, not permanent chrome. The editor remains calm and native; advanced capability appears only when the user enters a focused workflow. Security controls must remain visible, local-first, bounded, and fail closed for managed high-risk actions.
