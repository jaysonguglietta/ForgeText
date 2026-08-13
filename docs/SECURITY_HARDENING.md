# Security Hardening

ForgeText is a local macOS editor and developer workbench. It opens attacker-controlled files and repositories, can invoke local developer tools, can connect to remote systems, and can send selected context to AI providers. Those are explicit trust boundaries, not ordinary UI conveniences.

## Security Model

- Raw editing remains available in restricted workspaces.
- Workspace code execution, AI sends, remote commands, external formatting, and external plugins require a trusted workspace and remain subject to local and managed policy.
- Managed policy is restrictive: an invalid policy fails closed, and newly introduced high-risk capabilities are denied unless explicitly enabled.
- Safe Mode can disable external plugins, AI, remote access, terminal/task execution, and session restore for incident response or recovery.
- ForgeText does not treat a repository, plugin registry, AI rule file, settings bundle, HTTP response, or diagnostic destination as trusted merely because the user opened it.

## Capability Matrix

| Capability | Restricted workspace | Trusted workspace | Managed-policy control |
| --- | --- | --- | --- |
| Raw file editing | Allowed | Allowed | Core editing remains available |
| Automatic Git inspection | Disabled | Allowed with inert Git config | Workspace trust plus task controls |
| Git mutations and network operations | Blocked | User initiated | Workspace trust |
| Reviewed Git/AI patch | Blocked | Per-hunk approval plus `git apply --check` | Workspace trust and AI policy |
| Built-in JSON/XML/HTTP formatting | Allowed | Allowed | Core editing |
| External formatter process | Blocked | User initiated | `allowExternalFormatters` |
| AI request | Blocked | User initiated/reviewable | Provider, endpoint, model, and context policy |
| HTTP request runner | Blocked | User initiated; private targets require confirmation | Runner, host, and private-network policy |
| Workspace/plugin task | Blocked | User initiated | Task and executable allowlists |
| Remote command or agent install | Blocked | User initiated | Remote capability policy |
| External plugin | Built-in non-task plugins only | Origin and capability checks | Signature, digest, author, origin, and task policy |

## Process Execution

All subprocesses use bounded concurrent output drains, bounded input, and operation-specific timeouts. A timed-out process is terminated and then killed if it does not exit. This avoids both pipe deadlocks and the main-run-loop reentrancy that previously occurred around `Process.waitUntilExit()`.

Git is invoked with repository-controlled fsmonitor hooks, hooks paths, external diff/text-conversion drivers, pagers, editors, interactive prompts, and the `ext` transport disabled. Diff operations also use `--no-ext-diff` and `--no-textconv`.

Workspace tasks must use a simple executable name. ForgeText resolves that name, follows symlinks, and only launches an executable regular file under an approved system, Homebrew, `/usr/local`, or Xcode toolchain root. Task-capable plugin installation requires an explicit capability warning.

External formatting is available only in a trusted workspace. Prettier runs with `--no-config` and `--no-editorconfig` so an opened repository cannot silently load formatter plugins or executable configuration.

## Network Boundaries

The shared network service enforces scheme and exact-host allowlists, rejects URL-embedded credentials, resolves destination addresses before sending, blocks redirects, applies request timeouts, requests identity encoding, and streams responses into a hard byte limit.

- Cloud AI credentials are pinned to the official OpenAI, Anthropic, or Gemini host. Custom cloud endpoints must use an OpenAI-compatible profile.
- Local-model profiles must resolve only to private or loopback addresses and do not require an API key.
- Public requests that resolve to loopback, link-local, private, multicast, or reserved ranges are blocked.
- The HTTP runner requires a one-time confirmation for a private destination and can be limited to exact hosts by managed policy.
- Remote plugin registries require HTTPS, cannot redirect, are capped at 1 MB, and cannot supply executable tasks.

DNS is validated before `URLSession` connects, but the system resolver performs the connection-time lookup. Environments that require protection against adversarial DNS rebinding should additionally enforce an outbound proxy or host firewall and use managed exact-host allowlists.

## Files, Secrets, And Privacy

- Security-sensitive reads use `O_NOFOLLOW`, require a regular file, and read no more than the operation limit plus one detection byte.
- Files above the editable limit use bounded `pread` windows and capped streaming search; symlinks and non-regular files are rejected before chunked viewing.
- Workspace indexing/search skips symlinks, special files, oversized files, and common dependency/build directories.
- AI rule files are contained within the workspace, cannot be symlinks, are capped individually and in aggregate, and are limited in count.
- Scoped AI rules are limited by file size, rule count, matched instruction size, normalized workspace-relative paths, extensions, and known quick-action task identifiers.
- AI provider keys and the sensitive-state encryption key use Keychain items marked `WhenUnlockedThisDeviceOnly` and are cached for the process lifetime to avoid repeated prompts.
- Sensitive local state is encrypted with AES-GCM and stored with mode `0600`; application data directories use mode `0700`.
- Settings and sync exports omit AI keys, trust decisions, registry state, workspace sessions, and AI conversation history.
- Diagnostic exports hash or redact local paths and credentials and omit document and AI conversation contents.

Portable mode is opt-in. An adjacent `ForgeTextData` directory requires a `.forgetext-portable` marker; explicit portable directories use `FORGETEXT_PORTABLE_DATA_DIR`. The directory must already exist, be owned by the current user, not be a symlink, and have mode `0700`. Plaintext legacy sensitive-state files are never auto-migrated from portable storage.

## Managed Policy And Plugins

Managed policy files must be regular, non-symlink files no larger than 1 MB, owned by root or the current user, and not writable by group or other accounts. Unsupported, malformed, or insecure policy files activate a fail-closed policy.

Managed Macs can instead force `ManagedPolicyJSON` in the `com.jaysonguglietta.ForgeText` preference domain. ForgeText ignores non-forced values, caps the forced string at 1 MB, validates schema version 1, gives it precedence over policy files, and fails closed when it is invalid.

Policies can carry an Ed25519 signature over canonical JSON. Trusted administrator keys come from forced preferences or the deployment environment; once configured, unsigned or incorrectly signed policy fails closed. Only verified or forced MDM policy can redirect Sparkle to an exact allowed HTTPS feed.

Enterprise activity events are privacy-redacted, serialized off the UI thread, encrypted at rest, capped, retention bounded, and exportable as user-only JSONL when policy allows. This local log is not claimed to be tamper-proof against an already-compromised user account.

External plugin manifests can carry:

- `signingPublicKey`: Base64-encoded raw Ed25519 public key.
- `signature`: Base64 Ed25519 signature over compact, sorted-key JSON after removing `signature` while retaining `signingPublicKey`.

ForgeText records the SHA-256 digest of those same canonical bytes. Managed policy can require a valid signature and independently allowlist signing keys, canonical digests, authors, and task executable names. An author allowlist without trusted signing keys is rejected because an unsigned manifest can claim any author.

## Build And Supply Chain

- Sparkle is exactly pinned to `2.9.4`, which includes the 2.9.2 fixes for the 2026 delta-symlink and installer-connection advisories.
- The Xcode project enables hardened runtime.
- Public DMG creation requires a Developer ID Application identity and a `notarytool` Keychain profile, verifies the app signature/runtime, signs and notarizes the DMG, staples and validates the ticket, runs Gatekeeper assessment, and writes a SHA-256 checksum.
- Release tooling also emits provenance metadata for the exact app/DMG/checksum/dependency state promoted by the build.
- GitHub CI runs the test suite, CodeQL for Swift, dependency review, and weekly Dependabot checks. Third-party workflow actions are pinned to immutable commits.

## Residual Risks

- ForgeText is not App Sandbox-contained. Developer workflows require broad user-selected file access and subprocess execution, so workspace trust, policy, and Safe Mode are the primary containment boundaries.
- A user-approved workspace task or remote command is intentional code execution with that user's privileges. Policy should disable these capabilities where they are not required.
- DNS preflight does not cryptographically pin the connection address. High-assurance deployments should combine exact-host policy with an egress proxy or endpoint firewall.
- Local administrators and malware already running as the user can tamper with user-writable toolchains or process memory. ForgeText's controls are not an endpoint-detection or privilege-separation system.
- Signing and notarization are enforced by the public release script but require organization-held Apple and Sparkle credentials that are not stored in this repository.

## Security Verification

Run the full local suite:

```bash
xcodebuild test \
  -project ForgeText.xcodeproj \
  -scheme ForgeText \
  -derivedDataPath DerivedData \
  -clonedSourcePackagesDirPath DerivedData/SourcePackages \
  -disableAutomaticPackageResolution \
  -skipPackageUpdates \
  CODE_SIGNING_ALLOWED=NO
```

The regression suite covers output truncation, process timeout, oversized input, inert Git fsmonitor behavior, selected-hunk staging, checked AI patches, forced and signed policy, scoped AI rules, invalid-policy fail-closed behavior, private-network blocking, exact host matching, URL credential rejection, plugin signature tampering, declarative language packs, bounded/chunked file reads, SFTP argument safety, trust retargeting, SSH option injection, Git clone option injection, named-pipe handling, and protected persistence. The separate `ForgeTextUITests` scheme provides macOS shell/accessibility smoke coverage.
