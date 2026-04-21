# ForgeText Updates

ForgeText uses Sparkle for direct-download macOS updates and GitHub Releases for public DMG downloads.

## In-App Release Readiness

ForgeText 1.1 includes `Tools > Release Readiness`.

Use that panel before publishing a public build. It checks:

- app version and build metadata
- Sparkle `SUFeedURL`
- Sparkle `SUPublicEDKey`
- `Scripts/build_release_dmg.sh`
- `docs/appcast.xml`
- `docs/UPDATES.md`
- DMG files in `dist/`

Warnings are informational. Failures are blockers for a clean public update flow.

## Public Repo Update Plan

The intended public update flow is:

1. Build a signed `Release` app bundle.
2. Package it as a `.dmg` for GitHub Releases.
3. Upload that DMG to a GitHub Release.
4. Generate a Sparkle appcast that points at the release asset URL.
5. Host the appcast on GitHub Pages.
6. Let ForgeText's built-in `Check for Updates...` command query that feed.

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

1. Build the GitHub Release archive:

   ```bash
   ./Scripts/build_release_dmg.sh
   ```

2. Confirm `Tools > Release Readiness` has no blockers.
3. Create a GitHub Release such as `V1.1`.
4. Upload `dist/ForgeText-<version>-<build>.dmg` as a release asset.
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
- If `SUFeedURL` exists but `SUPublicEDKey` is missing, ForgeText shows setup guidance instead of starting Sparkle in a half-configured state.
- If the appcast URL returns HTTP 404, enable GitHub Pages or push `docs/appcast.xml`.
- For real public distribution, use Developer ID signing, hardened runtime, and notarization.

## Diagnostic Support

ForgeText 1.1 includes `Tools > Export Diagnostic Bundle...`.

Use this when troubleshooting release or updater issues. The bundle includes release-readiness state, app version, workspace paths, recent activity, and index summaries. It intentionally excludes document contents and AI API keys.
