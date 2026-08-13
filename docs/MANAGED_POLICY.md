# Managed Policy

ForgeText can be administered with a forced MDM preference or a local `managed-policy.json` file for enterprise or team-managed installs.

This policy layer is designed to let IT, platform, and security teams control higher-risk features without removing the core local editing experience.

ForgeText also has local user-facing controls in `Workbench + Advanced`. Managed policy and local advanced settings combine conservatively:

- the managed policy can further restrict local settings
- a local user setting cannot override a stricter managed policy
- the UI should explain whether a block came from policy or local advanced safety settings

## What It Can Control

Current policy enforcement covers:

- AI availability
- cloud AI vs local models
- allowed AI provider kinds
- allowed AI model-name prefixes
- exact AI endpoint host allowlists
- organization-approved AI provider profiles and optional exact-profile enforcement
- whether selection, current-file, and workspace-rules context can be sent to AI
- external formatter execution
- HTTP request execution, exact destination hosts, and private-network access
- workspace-local plugins
- user-installed plugins
- custom plugin registries
- file-based plugin registries
- task-capable plugins
- approved plugin registry hosts
- approved plugin authors
- required Ed25519 signatures, signing keys, and canonical manifest digests
- approved task executable names
- managed private plugin catalogs with per-catalog trusted signing keys and task capability policy
- embedded terminal access
- workspace task execution
- supervised language-server startup
- debug-adapter verification
- development-container startup
- authenticated GitHub CLI integration
- remote file access
- remote search
- remote commands
- remote agent install
- manual update checks
- stable, beta, or internal update rings and exact signed-policy feed selection
- diagnostic bundle export
- local encrypted audit retention, detail redaction, and audit export

## Discovery Order

ForgeText resolves managed policy in this order:

1. forced `ManagedPolicyJSON` in the `com.jaysonguglietta.ForgeText` preference domain
2. `/Library/Application Support/ForgeText/managed-policy.json`
3. `FORGETEXT_MANAGED_POLICY_FILE`
4. the local ForgeText app-data directory

The MDM value must be a forced string containing policy schema version 1 JSON. ForgeText ignores a user-created, non-forced default with this name. A malformed or unsupported forced value fails closed. Administrators can force `ManagedPolicyTrustedSigningKeys` and `RequireSignedManagedPolicy`; deployment automation can provide comma-separated trust roots through `FORGETEXT_POLICY_TRUSTED_SIGNING_KEYS`. Once a trust root is configured, unsigned or incorrectly signed policy fails closed. See [Enterprise Deployment](./ENTERPRISE_DEPLOYMENT.md) for rollout guidance.

You can see the active source path in `Workspace > Workspace Center`.

## Example File

Start from [managed-policy.example.json](./managed-policy.example.json) and tailor it for your environment.

Example:

```json
{
  "version": 1,
  "organizationName": "Acme Infrastructure",
  "notes": "Local AI only. Workspace plugins and remote commands are blocked on managed laptops.",
  "features": {
    "allowEmbeddedTerminal": true,
    "allowWorkspaceTasks": true,
    "allowExternalFormatters": false,
    "allowHTTPRequestRunner": true,
    "allowPrivateNetworkRequests": false,
    "allowLanguageServers": true,
    "allowDebugAdapters": false,
    "allowDevContainers": false,
    "allowGitHubIntegration": true,
    "allowedHTTPRequestHosts": [
      "api.acme.example"
    ]
  },
  "ai": {
    "isEnabled": true,
    "allowsCloudProviders": false,
    "allowsLocalModels": true,
    "allowsSelectionContext": true,
    "allowsCurrentDocumentContext": false,
    "allowsWorkspaceRulesContext": true,
    "allowedProviderKinds": [
      "ollama",
      "openAICompatible"
    ],
    "allowedModelPrefixes": [
      "qwen",
      "llama",
      "deepseek"
    ],
    "allowedEndpointHosts": [
      "127.0.0.1",
      "ai.acme.internal"
    ],
    "enforceApprovedProviders": true,
    "approvedProviders": [
      {
        "id": "9d43a540-2158-4a31-89e0-3ea8107adb41",
        "name": "Managed Local Model",
        "kind": "ollama",
        "connectionMode": "localModel",
        "baseURLString": "http://127.0.0.1:11434",
        "model": "qwen2.5-coder:7b",
        "temperature": 0.2
      }
    ]
  },
  "plugins": {
    "allowWorkspacePlugins": false,
    "allowUserInstalledPlugins": true,
    "allowCustomRegistries": true,
    "allowsFileRegistries": false,
    "allowTaskCapablePlugins": false,
    "allowedRegistryHosts": [
      "plugins.acme.example"
    ],
    "allowedPluginAuthors": [
      "ForgeText",
      "Acme Platform"
    ],
    "requireSignedPlugins": true,
    "allowedPluginSigningKeys": [
      "BASE64_ED25519_PUBLIC_KEY"
    ],
    "allowedTaskExecutables": [
      "git",
      "swift",
      "npm"
    ],
    "managedCatalogs": [
      {
        "name": "Acme Approved Plugins",
        "source": "https://plugins.acme.example/catalog.json",
        "trustedSigningKeys": [
          "BASE64_ED25519_PUBLIC_KEY"
        ],
        "allowsTaskPlugins": false
      }
    ]
  },
  "remote": {
    "allowRemoteFiles": true,
    "allowRemoteSearch": true,
    "allowRemoteCommands": false,
    "allowRemoteAgentInstall": false
  },
  "updates": {
    "allowUpdateChecks": true,
    "ring": "stable",
    "feedURL": "https://updates.acme.example/stable/appcast.xml",
    "allowedFeedHosts": [
      "updates.acme.example"
    ]
  },
  "support": {
    "allowDiagnosticBundles": true,
    "includePolicySummaryInDiagnostics": true,
    "allowAuditExport": true,
    "auditRetentionDays": 30,
    "includeActivityDetailsInAudit": false
  }
}
```

## Operational Notes

- Policy files must be regular non-symlink files, no larger than 1 MB, owned by root or the current user, and not group/world writable.
- Malformed, unsupported, oversized, symlinked, incorrectly owned, or insecurely writable policy files activate a fail-closed policy. Core editing remains available, but managed high-risk capabilities are denied.
- High-risk fields added after the initial policy schema, including external formatters, the HTTP runner, language servers, debug adapters, development containers, and GitHub integration, require an explicit `true` when any managed policy is active.
- `Engineering Workbench > Enterprise` shows the effective result after managed policy, workspace trust, Safe Mode, and local hardening settings are combined.
- Host allowlists use normalized exact matches. Listing `example.com` does not authorize `attacker.example.com`.
- Editing still works even when stricter policy controls are active.
- Blocked features stay visible where useful, but ForgeText explains the restriction instead of silently failing.
- `Tools > Reload Managed Policy` forces a fresh read after the file changes.
- Diagnostic bundle export can include a policy summary for support workflows without copying secrets or document contents.
- `Workbench + Advanced` remains useful on managed installs for allowed local preferences such as runtime mode, raw-view defaults, or autosave delay, but policy wins when both apply.
- A local unsigned policy may restrict update checks but cannot redirect the updater. Custom feed URLs require a verified policy signature or a forced MDM policy and must use an exact allowed HTTPS host.
- Audit retention is clamped to 1-365 days. Exported JSONL is written with user-only permissions; sensitive-looking details are redacted before encrypted local persistence.

## Signed Policy Artifacts

The optional top-level `signature` uses the same canonical Ed25519 envelope as signed plugin manifests. ForgeText removes the `signature` field, encodes the remaining policy as compact sorted-key JSON, verifies the raw Ed25519 signature, and records the canonical SHA-256 digest and verified key in the Enterprise workbench.

Do not paste a placeholder signature into the example policy. Generate and sign the final canonical artifact in organization-controlled release tooling, then distribute the corresponding public key through forced `ManagedPolicyTrustedSigningKeys` or the deployment environment. Rotate keys by trusting old and new keys during a bounded overlap, redistributing signed policy, and removing the retired key after fleet validation.

## Plugin Provenance

An external plugin or registry entry can include a Base64 raw Ed25519 `signingPublicKey` and a Base64 `signature`. The signature covers compact, sorted-key JSON after removing `signature` while retaining `signingPublicKey`. ForgeText also calculates a SHA-256 digest over those canonical bytes.

Policy can enforce provenance with:

- `requireSignedPlugins`
- `allowedPluginSigningKeys`
- `allowedPluginManifestDigests`
- `allowedPluginAuthors`
- `allowedTaskExecutables`

An author allowlist must be paired with at least one allowed signing key; otherwise an unsigned manifest could simply claim an approved author. An empty configured digest or signing-key list authorizes nothing.

Remote registries are HTTPS-only, use exact-host and public-address checks, reject redirects, and are capped at 1 MB. Remote registries cannot distribute task-capable plugins. Local file registries can contain tasks, but installation shows a capability warning and execution still requires workspace trust and policy approval.

## Current Limitations

This is a local enterprise-policy enforcement layer, not a central device-management system.

It does not currently provide:

- a ForgeText-hosted centralized policy service
- vendor-specific MDM profile generation or assignment
- centralized plugin or policy certificate issuance, rotation, or revocation
- centralized audit ingestion, admin telemetry, or fleet reporting

Use an existing MDM product to force `ManagedPolicyJSON`, assign devices, sign profiles, and manage rollback. ForgeText validates and enforces the resulting local preference.
