# ForgeText Icon Candidates

This folder contains preview renders for alternate ForgeText app icons. Each candidate also has a complete macOS `.appiconset` in `ForgeText/Assets.xcassets`.

Current active icon: `floppy-script`

## Candidates

- `retro-crt`: beige terminal monitor, scanlines, and chunky 90s text energy.
- `floppy-script`: bright 3.5-inch floppy disk with a code-note label.
- `pixel-forge`: forged document, caret, hammer, and pixel sparks.
- `neon-notebook`: neon browser/editor window layered over a notebook page.

## Generate Candidates

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer CLANG_MODULE_CACHE_PATH=DerivedData/ModuleCache /usr/bin/xcrun swift Scripts/generate_app_icon_candidates.swift
```

## Install One Candidate As The Active App Icon

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer CLANG_MODULE_CACHE_PATH=DerivedData/ModuleCache /usr/bin/xcrun swift Scripts/generate_app_icon_candidates.swift --install retro-crt
```

Replace `retro-crt` with `floppy-script`, `pixel-forge`, or `neon-notebook`. The install command overwrites `ForgeText/Assets.xcassets/AppIcon.appiconset`, so commit or back up the current active icon first if you want to preserve it.
