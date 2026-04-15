#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_SCRIPT="$ROOT_DIR/Scripts/build_local_release.sh"
APP_PATH="$ROOT_DIR/DerivedData/Build/Products/Release/ForgeText.app"
OUTPUT_DIR="$ROOT_DIR/dist"
SHOULD_OPEN=0
SKIP_BUILD=0
VOLUME_NAME="ForgeText"

usage() {
  cat <<EOF
Usage: $(basename "$0") [--skip-build] [--output-dir PATH] [--open]

Builds ForgeText in Release mode and packages it as a DMG suitable for GitHub Releases.

Options:
  --skip-build        Package the existing Release app without rebuilding
  --output-dir PATH   Write the DMG into a custom folder
  --open              Reveal the resulting DMG in Finder
  --help              Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-build)
      SKIP_BUILD=1
      shift
      ;;
    --output-dir)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --output-dir" >&2
        exit 1
      fi
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --open)
      SHOULD_OPEN=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ "$SKIP_BUILD" -eq 0 ]]; then
  "$BUILD_SCRIPT"
fi

if [[ ! -d "$APP_PATH" ]]; then
  echo "Expected Release app was not found:" >&2
  echo "  $APP_PATH" >&2
  exit 1
fi

INFO_PLIST="$APP_PATH/Contents/Info.plist"
SHORT_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$INFO_PLIST")
BUILD_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$INFO_PLIST")
ARTIFACT_BASENAME="ForgeText-${SHORT_VERSION}-${BUILD_VERSION}"

mkdir -p "$OUTPUT_DIR"

STAGING_DIR=$(mktemp -d "${TMPDIR:-/tmp}/forgetext-dmg.XXXXXX")
DMG_PATH="$OUTPUT_DIR/${ARTIFACT_BASENAME}.dmg"

cleanup() {
  rm -rf "$STAGING_DIR"
}

trap cleanup EXIT

ditto "$APP_PATH" "$STAGING_DIR/ForgeText.app"
ln -s /Applications "$STAGING_DIR/Applications"

cat > "$STAGING_DIR/Install ForgeText.txt" <<EOF
ForgeText ${SHORT_VERSION} (${BUILD_VERSION})

To install:
1. Drag ForgeText.app into Applications
2. Launch ForgeText from Applications

Repository:
https://github.com/jaysonguglietta/ForgeText
EOF

rm -f "$DMG_PATH"

hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH" > /dev/null

echo "Built DMG:"
echo "  $DMG_PATH"
echo
echo "Suggested next step:"
echo "  Upload this DMG to a GitHub Release instead of committing it into the repo."

if [[ "$SHOULD_OPEN" -eq 1 ]]; then
  open -R "$DMG_PATH"
fi
