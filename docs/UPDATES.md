# ForgeText Updates

ForgeText uses Sparkle `2.9.4` for direct-download macOS updates and GitHub Releases for public DMG downloads. Sparkle is exact-version pinned in `project.yml` and `Package.resolved`.

Managed fleets can disable in-app checks or select a stable, beta, or internal ring through verified policy and distribute the same signed/notarized app with MDM. A custom feed must use HTTPS and an exact allowed host; unsigned local policy cannot redirect the updater. See [Enterprise Deployment](./ENTERPRISE_DEPLOYMENT.md) for managed and air-gapped channel guidance.

## In-App Release Readiness

ForgeText includes `Tools > Release Readiness`.

Use that panel before publishing a public build. It checks:

- app version and build metadata
- Sparkle `SUFeedURL`
- Sparkle `SUPublicEDKey`
- `Scripts/build_release_dmg.sh`
- `docs/appcast.xml`
- `docs/UPDATES.md`
- DMG files in `dist/`
- hardened runtime plus Developer ID, notarization, stapling, Gatekeeper, and checksum gates in the project and release script
- release provenance metadata generated beside the DMG/checksum

Warnings are informational. Failures are blockers for a clean public update flow.

## Public Repo Update Plan

The intended public update flow is:

1. Build a Developer ID signed `Release` app with hardened runtime.
2. Package and sign the `.dmg`.
3. Submit the DMG to Apple notarization, staple the ticket, validate it, and run Gatekeeper assessment.
4. Generate and retain the SHA-256 checksum.
5. Generate release provenance and upload the DMG, checksum, and provenance metadata to a GitHub Release.
6. Generate a signed Sparkle appcast that points at the release asset URL.
7. Host the appcast on GitHub Pages.
8. Let ForgeText's built-in `Check for Updates...` command query that feed.

## Expected Public URLs

- Repo: `https://github.com/jaysonguglietta/ForgeText`
- Appcast: `https://jaysonguglietta.github.io/ForgeText/appcast.xml`
- Latest release page: `https://github.com/jaysonguglietta/ForgeText/releases/latest`

## One-Time Sparkle Setup

1. Enable GitHub Pages for this repo.

   Recommended source:

   - branch: `main`
   - folder: `/docs`

2. Add Sparkle's public signing key to `Info.plist`.

   - Generate keys with Sparkle's `generate_keys` tool.
   - Copy the printed public key into `SUPublicEDKey`.

3. Keep the private Sparkle signing key safe in your login keychain on your release Mac.

4. Build release archives with a monotonically increasing `CFBundleVersion`.

5. Create a Developer ID Application certificate and a `notarytool` Keychain profile:

   ```bash
   xcrun notarytool store-credentials forgetext-notary \
     --apple-id "release@example.com" \
     --team-id "TEAMID"
   ```

## Local Install Flow

For your own Mac, use:

```bash
./Scripts/build_local_release.sh --install
```

This installs:

```text
/Applications/ForgeText.app
```

Local installs do not require a DMG, GitHub Release, appcast update, notarization, or Sparkle feed.

## Publishing A Public Release

1. Build, sign, notarize, staple, and validate the GitHub Release archive:

   ```bash
   DEVELOPER_ID_APPLICATION="Developer ID Application: Example Corp (TEAMID)" \
   NOTARYTOOL_PROFILE="forgetext-notary" \
   ./Scripts/build_release_dmg.sh
   ```

2. Confirm the script produced `.dmg`, `.dmg.sha256`, and release-provenance output, and `Tools > Release Readiness` has no blockers.
3. Create a GitHub Release such as `V1.2.1`.
4. Upload `dist/ForgeText-<version>-<build>.dmg`, its `.sha256`, and generated provenance metadata as release assets.
5. Put the DMG, and any historical release archives you want Sparkle to know about, in a local staging folder.
6. Run Sparkle's `generate_appcast` against that folder.
7. Replace `docs/appcast.xml` with the generated appcast.
8. Push `docs/appcast.xml` so GitHub Pages serves it.
9. Use `Check for Updates...` in ForgeText to verify the public feed.

## Why DMG Plus GitHub Releases

- A DMG gives macOS users the familiar drag-to-Applications install flow.
- GitHub Releases is the right home for downloadable binaries.
- Keeping DMGs out of git history keeps the repository smaller and cleaner.
- Sparkle can point directly at the same GitHub Release asset URL that users download manually.

## Appcast Notes

- The app-side updater is intentionally conservative.
- ForgeText uses Sparkle 2.9.4 or newer. Do not downgrade to 2.9.1 or earlier because those versions are affected by the 2026 binary-delta symlink traversal and installer-connection advisories.
- If `SUFeedURL` exists but `SUPublicEDKey` is missing, ForgeText shows setup guidance instead of starting Sparkle in a half-configured state.
- If the appcast URL returns HTTP 404, enable GitHub Pages or push `docs/appcast.xml`.
- `Scripts/build_release_dmg.sh` refuses to publish without Developer ID signing, hardened runtime, notarization, stapling, Gatekeeper validation, a SHA-256 checksum, and release provenance generation.

## Diagnostic Support

ForgeText includes `Tools > Export Diagnostic Bundle...`.

Use this when troubleshooting release or updater issues. The bundle includes release-readiness state, app version, redacted workspace labels, recent activity, and index summaries. It intentionally excludes raw filesystem paths, document contents, and AI API keys.

On managed installs, the diagnostic bundle can also include a policy summary so support teams can tell whether update checks or related flows were blocked by local admin policy.
