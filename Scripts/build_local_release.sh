#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/ForgeText.xcodeproj"
PROJECT_SPEC="$ROOT_DIR/project.yml"
SCHEME="ForgeText"
DERIVED_DATA_PATH="$ROOT_DIR/DerivedData"
CONFIGURATION="Release"
APP_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/ForgeText.app"
INSTALL_DIR=""
SHOULD_OPEN=0

usage() {
  cat <<EOF
Usage: $(basename "$0") [--install] [--install-dir PATH] [--open]

Builds ForgeText in Release mode for local use.

Options:
  --install           Copy the built app into /Applications
  --install-dir PATH  Copy the built app into a custom folder
  --open              Open the resulting app after the build
  --help              Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --install)
      INSTALL_DIR="/Applications"
      shift
      ;;
    --install-dir)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --install-dir" >&2
        exit 1
      fi
      INSTALL_DIR="$2"
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

DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

echo "Generating project..."
DEVELOPER_DIR="$DEVELOPER_DIR" xcodegen generate --spec "$PROJECT_SPEC" > /dev/null

echo "Building ForgeText ($CONFIGURATION)..."
DEVELOPER_DIR="$DEVELOPER_DIR" \
  xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  build > /dev/null

if [[ ! -d "$APP_PATH" ]]; then
  echo "Expected app was not produced at:" >&2
  echo "  $APP_PATH" >&2
  exit 1
fi

echo "Built app:"
echo "  $APP_PATH"

if [[ -n "$INSTALL_DIR" ]]; then
  mkdir -p "$INSTALL_DIR"
  rm -rf "$INSTALL_DIR/ForgeText.app"
  ditto "$APP_PATH" "$INSTALL_DIR/ForgeText.app"
  touch "$INSTALL_DIR/ForgeText.app"
  echo "Installed app:"
  echo "  $INSTALL_DIR/ForgeText.app"
fi

if [[ "$SHOULD_OPEN" -eq 1 ]]; then
  TARGET_APP="$APP_PATH"
  if [[ -n "$INSTALL_DIR" ]]; then
    TARGET_APP="$INSTALL_DIR/ForgeText.app"
  fi
  open "$TARGET_APP"
fi
