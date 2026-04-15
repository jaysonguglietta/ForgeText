# ForgeText Updates

ForgeText uses Sparkle for direct-download macOS updates.

## Public repo update plan

The intended public update flow is:

1. Publish a signed `Release` build of `ForgeText.app`
2. Package it as a `.dmg` for GitHub Releases
3. Upload that DMG to a GitHub Release
4. Generate a Sparkle appcast that points at the release asset URL
5. Host the appcast on GitHub Pages
6. Let ForgeText's built-in `Check for Updates...` command query that feed

## Expected public URLs

- Repo: `https://github.com/jaysonguglietta/ForgeText`
- Appcast: `https://jaysonguglietta.github.io/ForgeText/appcast.xml`
- Latest release page: `https://github.com/jaysonguglietta/ForgeText/releases/latest`

## One-time Sparkle setup

1. Enable GitHub Pages for this repo.
   Recommended source:
   - branch: `main`
   - folder: `/docs`

2. Add Sparkle's public signing key to `Info.plist`.
   - Generate keys with Sparkle's `generate_keys` tool
   - Copy the printed public key into `SUPublicEDKey`

3. Keep the private Sparkle signing key safe in your login keychain on your release Mac.

4. Build release archives with a monotonically increasing `CFBundleVersion`.

## Publishing a release

1. Build the GitHub Release archive:

   ```bash
   ./Scripts/build_release_dmg.sh
   ```

2. Create a GitHub Release such as `v1.0.0`
3. Upload the generated `dist/ForgeText-<version>-<build>.dmg` as a release asset
4. Put the DMG, and any historical release archives you want Sparkle to know about, in a local staging folder
5. Run Sparkle's `generate_appcast` against that folder
6. Replace the placeholder `docs/appcast.xml` in this repo with the generated appcast
7. Push the updated `docs/appcast.xml` so GitHub Pages serves it

## Why DMG + GitHub Releases

- A DMG gives macOS users the familiar drag-to-Applications install flow
- GitHub Releases is the right home for distributable binaries
- Keeping DMGs out of git history keeps the repository smaller and cleaner
- Sparkle can point directly at the same GitHub Release asset URL that users download manually

## Notes

- The app-side updater is intentionally conservative:
  - if `SUFeedURL` exists but `SUPublicEDKey` is still missing, ForgeText shows setup guidance instead of starting Sparkle in a half-configured state
- The placeholder `docs/appcast.xml` is valid RSS but intentionally contains no releases yet
- For real public distribution, use Developer ID signing, hardened runtime, and notarization
