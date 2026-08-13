#!/bin/zsh

set -euo pipefail

if [[ $# -lt 2 || $# -gt 3 ]]; then
  echo "Usage: $(basename "$0") ARTIFACT APP_BUNDLE [OUTPUT_JSON]" >&2
  exit 64
fi

ARTIFACT_PATH="$1"
APP_PATH="$2"
OUTPUT_PATH="${3:-$ARTIFACT_PATH.provenance.json}"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

if [[ ! -f "$ARTIFACT_PATH" ]]; then
  echo "Artifact does not exist: $ARTIFACT_PATH" >&2
  exit 66
fi
if [[ ! -d "$APP_PATH" ]]; then
  echo "App bundle does not exist: $APP_PATH" >&2
  exit 66
fi

json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

validate_json_value() {
  local label="$1"
  local value="$2"
  if [[ "$value" == *$'\n'* || "$value" == *$'\r'* || "$value" == *$'\t'* ]]; then
    echo "$label contains unsupported control characters." >&2
    exit 65
  fi
}

INFO_PLIST="$APP_PATH/Contents/Info.plist"
SHORT_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$INFO_PLIST")
BUILD_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$INFO_PLIST")
ARTIFACT_SHA=$(shasum -a 256 "$ARTIFACT_PATH" | awk '{print $1}')
DEPENDENCY_LOCK_SHA=""
PROJECT_DEFINITION_SHA=""
if [[ -f "$ROOT_DIR/ForgeText.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved" ]]; then
  DEPENDENCY_LOCK_SHA=$(shasum -a 256 "$ROOT_DIR/ForgeText.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved" | awk '{print $1}')
fi
if [[ -f "$ROOT_DIR/project.yml" ]]; then
  PROJECT_DEFINITION_SHA=$(shasum -a 256 "$ROOT_DIR/project.yml" | awk '{print $1}')
fi
SOURCE_COMMIT=$(git -C "$ROOT_DIR" rev-parse HEAD)
SOURCE_DIRTY=false
if [[ -n "$(git -C "$ROOT_DIR" status --porcelain)" ]]; then
  SOURCE_DIRTY=true
fi
SIGNING_DETAILS=$(codesign --display --verbose=4 "$APP_PATH" 2>&1)
TEAM_ID=$(printf '%s\n' "$SIGNING_DETAILS" | awk -F= '/^TeamIdentifier=/{print $2; exit}')
CD_HASH=$(printf '%s\n' "$SIGNING_DETAILS" | awk -F= '/^CDHash=/{print $2; exit}')
AUTHORITY=$(printf '%s\n' "$SIGNING_DETAILS" | awk -F= '/^Authority=/{print $2; exit}')
GENERATED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

validate_json_value "Artifact filename" "$(basename "$ARTIFACT_PATH")"
validate_json_value "Application version" "$SHORT_VERSION"
validate_json_value "Application build" "$BUILD_VERSION"
validate_json_value "Team identifier" "$TEAM_ID"
validate_json_value "Code directory hash" "$CD_HASH"
validate_json_value "Signing authority" "$AUTHORITY"

cat > "$OUTPUT_PATH" <<EOF
{
  "schemaVersion": 1,
  "artifact": {
    "fileName": "$(json_escape "$(basename "$ARTIFACT_PATH")")",
    "sha256": "$(json_escape "$ARTIFACT_SHA")"
  },
  "application": {
    "name": "ForgeText",
    "version": "$(json_escape "$SHORT_VERSION")",
    "build": "$(json_escape "$BUILD_VERSION")",
    "teamIdentifier": "$(json_escape "$TEAM_ID")",
    "codeDirectoryHash": "$(json_escape "$CD_HASH")",
    "signingAuthority": "$(json_escape "$AUTHORITY")"
  },
  "source": {
    "repository": "https://github.com/jaysonguglietta/ForgeText",
    "commit": "$(json_escape "$SOURCE_COMMIT")",
    "dirty": $SOURCE_DIRTY,
    "dependencyLockSHA256": "$(json_escape "$DEPENDENCY_LOCK_SHA")",
    "projectDefinitionSHA256": "$(json_escape "$PROJECT_DEFINITION_SHA")"
  },
  "build": {
    "generatedAt": "$(json_escape "$GENERATED_AT")",
    "hardenedRuntimeRequired": true,
    "notarizationRequired": true,
    "sparkleSignatureRequired": true
  }
}
EOF

chmod 0644 "$OUTPUT_PATH"
echo "Wrote release provenance:"
echo "  $OUTPUT_PATH"
