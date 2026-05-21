# Managed Policy

ForgeText can be administered with a local `managed-policy.json` file for enterprise or team-managed installs.

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
- whether selection, current-file, and workspace-rules context can be sent to AI
- workspace-local plugins
- user-installed plugins
- custom plugin registries
- file-based plugin registries
- task-capable plugins
- approved plugin registry hosts
- approved plugin authors
- embedded terminal access
- workspace task execution
- remote file access
- remote search
- remote commands
- remote agent install
- manual update checks
- diagnostic bundle export

## Discovery Order

ForgeText looks for a managed policy file in this order:

1. `FORGETEXT_MANAGED_POLICY_FILE`
2. `/Library/Application Support/ForgeText/managed-policy.json`
3. the local ForgeText app-data directory

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
    "allowWorkspaceTasks": true
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
    ]
  },
  "remote": {
    "allowRemoteFiles": true,
    "allowRemoteSearch": true,
    "allowRemoteCommands": false,
    "allowRemoteAgentInstall": false
  },
  "updates": {
    "allowUpdateChecks": false
  },
  "support": {
    "allowDiagnosticBundles": true,
    "includePolicySummaryInDiagnostics": true
  }
}
```

## Operational Notes

- Editing still works even when stricter policy controls are active.
- Blocked features stay visible where useful, but ForgeText explains the restriction instead of silently failing.
- `Tools > Reload Managed Policy` forces a fresh read after the file changes.
- Diagnostic bundle export can include a policy summary for support workflows without copying secrets or document contents.
- `Workbench + Advanced` remains useful on managed installs for allowed local preferences such as runtime mode, raw-view defaults, or autosave delay, but policy wins when both apply.

## Current Limitations

This is the first enterprise-policy foundation, not a full device-management system yet.

It does not currently provide:

- signed policy bundles
- centralized policy distribution
- MDM profile generation
- private plugin marketplace signing
- admin telemetry or fleet reporting

Those are good next steps once the base policy schema and enforcement surface settle.
