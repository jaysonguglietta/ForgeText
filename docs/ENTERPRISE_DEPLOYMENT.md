# Enterprise Deployment

This guide covers the current local controls for deploying ForgeText on managed Macs. It is intentionally conservative: ForgeText does not claim to be a central management server.

## Recommended Baseline

1. Distribute a Developer ID signed, notarized, and stapled ForgeText build.
2. Pin the Sparkle public key and host a signed appcast, or disable update checks through policy and distribute updates with MDM.
3. Force `ManagedPolicyJSON` in the `com.jaysonguglietta.ForgeText` preferences domain, or install a root-owned policy file. For higher-assurance roles, also force `ManagedPolicyTrustedSigningKeys` and `RequireSignedManagedPolicy`.
4. Require signed external plugins and allowlist signing keys, canonical manifest digests, registry hosts, authors, and task executables.
5. Default cloud AI, remote commands, task-capable plugins, terminal access, and private-network HTTP requests to denied unless the role needs them.
6. Keep workspace trust a user-visible, per-root decision. Do not pre-trust broad home or shared-volume paths.
7. Explicitly decide whether managed roles may start language servers, debug adapters, development containers, and authenticated GitHub CLI operations.

## MDM Managed Preference

ForgeText accepts a forced macOS managed preference named `ManagedPolicyJSON`. The value is the complete policy JSON string and must use policy schema version 1.

Payload essentials:

```text
Preference domain: com.jaysonguglietta.ForgeText
Key: ManagedPolicyJSON
Value type: String
Enforcement: Forced / managed
```

ForgeText ignores a normal user default with this name. Only a value reported by macOS as forced is accepted. A forced value is capped at 1 MB, decoded with the same schema as the policy file, and fails closed when malformed or unsupported. Its displayed source is `mdm://ManagedPolicyJSON`.

Optional forced trust settings:

```text
Key: ManagedPolicyTrustedSigningKeys
Value type: Array of Base64 raw Ed25519 public keys, or one comma-separated String

Key: RequireSignedManagedPolicy
Value type: Boolean
Recommended high-assurance value: true
```

Deployment tooling may alternatively provide comma-separated public keys in `FORGETEXT_POLICY_TRUSTED_SIGNING_KEYS`. Do not place private signing keys on endpoint Macs.

Use your MDM vendor's custom-settings payload to deliver this preference. The exact profile envelope, signing, assignment, rollback, and escrow process is vendor-specific and should remain in the organization's device-management system rather than this repository.

## File Policy Alternative

Install a policy at:

```text
/Library/Application Support/ForgeText/managed-policy.json
```

The file must be a regular, non-symlink file no larger than 1 MB, owned by root or the current user, and not group/world writable. A forced MDM policy takes precedence over file discovery.

## Private Plugin Catalog

- Serve registries over HTTPS from exact allowlisted hosts.
- Sign each external manifest with an approved Ed25519 key.
- Pin approved keys and, for high-assurance deployments, canonical manifest digests.
- Rotate keys by temporarily allowing old and new keys, republishing manifests, then removing the old key.
- Remote registries cannot distribute task-capable plugins. Keep executable plugins in a tightly controlled local catalog and require explicit trust and policy approval.
- Declare organization-owned sources in `plugins.managedCatalogs`. Each managed catalog is HTTPS-only, can pin its own trusted signing keys, and can explicitly deny task-capable entries independent of global plugin policy.

## Signed Policy Promotion

1. Produce the final schema-version-1 policy without a `signature` field.
2. Encode it as compact JSON with sorted keys and sign those canonical bytes with Ed25519.
3. Attach the top-level signature envelope, including the public key, signature value, optional key ID, and signing time.
4. Distribute the public key as an MDM trust root before requiring signatures.
5. Confirm `Engineering Workbench > Enterprise` reports the expected canonical digest and verified key.
6. Rotate with an old/new trust overlap; never ship private keys or signing credentials in the app, repository, or MDM profile.

## AI Deployment Modes

- `Bring Your Own Key`: each user stores a cloud-provider key in their macOS Keychain. Keys are not written to settings, profile packs, sync bundles, logs, or diagnostic exports.
- `Local Model`: use an Ollama or OpenAI-compatible loopback endpoint without a key.
- Managed deployments can disable cloud providers, restrict provider kinds and model prefixes, pin exact endpoint hosts, and deny selection, file, workspace-rule, or Git-diff context.
- `approvedProviders` can publish organization-reviewed profiles and `enforceApprovedProviders` can require exact kind, mode, endpoint, and model matches.

## Update Channels And Air-Gapped Macs

- Direct channel: publish a signed Sparkle appcast and notarized DMG.
- Managed channel: disable in-app update checks and distribute the notarized app with MDM.
- Air-gapped channel: disable network features and update checks, distribute the app plus approved plugin manifests offline, and verify the DMG SHA-256 checksum and Apple signatures before promotion.
- Ringed channel: set `updates.ring` to `stable`, `beta`, or `internal`, and use a verified signed policy to select an exact HTTPS `feedURL` constrained by `allowedFeedHosts`. Unsigned local policy cannot redirect the updater.

## Local Audit Handling

- Enterprise activity events are privacy-redacted and encrypted in the ForgeText local data store.
- Policy can set 1-365 day retention, hide activity details, and allow or deny JSONL export.
- Exports use mode `0600` and are intended for controlled support collection. They are not a tamper-proof substitute for centralized endpoint telemetry.
- If central collection is required, ingest exported events through organization-owned tooling with documented access, retention, and deletion controls.

## Fleet Validation

On a representative managed Mac:

1. Open `Tools > Engineering Workbench > Enterprise` and confirm the policy source, canonical digest, signature state, update ring, and fleet checks.
2. Confirm prohibited AI, plugins, tasks, terminal, remote, HTTP, update, and support actions show a managed restriction.
3. Confirm language-server, debug-adapter, development-container, and GitHub decisions match the assigned policy and workspace trust state.
4. Confirm editing, raw view, local search, and safe file operations remain available.
5. Export a diagnostic bundle or audit JSONL only when policy allows it and verify document contents, API keys, and AI chats are absent.
6. Run the release-readiness checks against the exact artifact being distributed.

## Current Boundary

ForgeText enforces local signed policy and provides local diagnostics/audit export. It does not provide centralized telemetry, tenant accounts, remote attestation, automatic certificate rotation, or a fleet dashboard. Those controls must come from MDM, endpoint security, identity, artifact-signing, and monitoring systems around the app.
