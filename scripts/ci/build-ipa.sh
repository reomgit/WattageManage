#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
MODE="${1:-unsigned}"
if [[ "$MODE" != unsigned && "$MODE" != signed ]]; then
  echo "Usage: $0 [unsigned|signed]" >&2
  exit 1
fi

XCODE_MAJOR="$(xcodebuild -version | awk '/^Xcode / {split($2, parts, "."); print parts[1]}')"
if [[ "$XCODE_MAJOR" -lt 27 ]]; then
  echo "Wattage requires Xcode 27 or later. Select a compatible Xcode with xcode-select." >&2
  exit 1
fi
xcodebuild -version

OUTPUT_DIR="$ROOT/build/ci"
ARCHIVE_PATH="$OUTPUT_DIR/Wattage.xcarchive"
EXPORT_PATH="$OUTPUT_DIR/export"
mkdir -p "$OUTPUT_DIR"
# These are disposable paths wholly owned by this script.
rm -rf "$ARCHIVE_PATH" "$EXPORT_PATH" "$OUTPUT_DIR/Payload"
mkdir -p "$EXPORT_PATH"

BUILD_NUMBER="${BUILD_NUMBER:-1}"
if [[ ! "$BUILD_NUMBER" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]]; then
  echo "BUILD_NUMBER must contain one to three numeric components." >&2
  exit 1
fi

ARGS=(
  -project "$ROOT/WattageManage.xcodeproj"
  -scheme WattageManage
  -configuration Release
  -destination generic/platform=iOS
  -sdk iphoneos
  -archivePath "$ARCHIVE_PATH"
  -derivedDataPath "$OUTPUT_DIR/DerivedData"
  "CURRENT_PROJECT_VERSION=$BUILD_NUMBER"
)

if [[ -n "${RELEASE_TAG:-}" ]]; then
  VERSION="${RELEASE_TAG#v}"
  if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; then
    echo "Release tags must be vMAJOR.MINOR or vMAJOR.MINOR.PATCH (for example v1.0.0)." >&2
    exit 1
  fi
  ARGS+=("MARKETING_VERSION=$VERSION")
fi

if [[ "$MODE" == unsigned ]]; then
  ARGS+=(CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= DEVELOPMENT_TEAM=)
else
  : "${WATTAGE_TEAM_ID:?Run install-signing.sh first}"
  : "${WATTAGE_APP_PROFILE:?Missing app provisioning profile}"
  : "${WATTAGE_WIDGET_PROFILE:?Missing widget provisioning profile}"
  : "${SIGNING_KEYCHAIN_PATH:?Missing temporary signing keychain}"
  : "${EXPORT_OPTIONS_PATH:?Missing export options}"
  ARGS+=(
    CODE_SIGN_STYLE=Manual
    CODE_SIGN_IDENTITY=Apple\ Distribution
    "DEVELOPMENT_TEAM=$WATTAGE_TEAM_ID"
    "WATTAGE_APP_PROFILE=$WATTAGE_APP_PROFILE"
    "WATTAGE_WIDGET_PROFILE=$WATTAGE_WIDGET_PROFILE"
    "OTHER_CODE_SIGN_FLAGS=--keychain $SIGNING_KEYCHAIN_PATH"
  )
fi

xcodebuild -quiet "${ARGS[@]}" archive 2>&1 | tee "$OUTPUT_DIR/archive.log"
APP_PATH="$ARCHIVE_PATH/Products/Applications/WattageManage.app"
if [[ ! -d "$APP_PATH/PlugIns/WattageWidgets.appex" ]]; then
  echo "Archive is missing the app or its widget extension." >&2
  exit 1
fi

if [[ "$MODE" == unsigned ]]; then
  mkdir -p "$OUTPUT_DIR/Payload"
  ditto --norsrc --noextattr "$APP_PATH" "$OUTPUT_DIR/Payload/WattageManage.app"
  ditto -c -k --norsrc --noextattr --keepParent "$OUTPUT_DIR/Payload" "$EXPORT_PATH/Wattage-unsigned.ipa"
else
  xcodebuild -exportArchive -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" -exportOptionsPlist "$EXPORT_OPTIONS_PATH" \
    2>&1 | tee "$OUTPUT_DIR/export.log"
  mv "$EXPORT_PATH/WattageManage.ipa" "$EXPORT_PATH/Wattage-signed.ipa"
  codesign --verify --deep --strict "$APP_PATH"
fi

unzip -tq "$EXPORT_PATH/Wattage-$MODE.ipa"
(cd "$EXPORT_PATH" && shasum -a 256 ./*.ipa > SHA256SUMS)
echo "IPA and SHA256SUMS are available in $EXPORT_PATH"
if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  {
    echo "### Wattage $MODE IPA"
    echo
    echo "Archive includes the app and WattageWidgets extension. Download the artifact from this run."
    if [[ "$MODE" == unsigned ]]; then
      echo "The IPA requires re-signing with compatible Apple profiles before it can be installed."
    fi
    echo
    echo '```'
    cat "$EXPORT_PATH/SHA256SUMS"
    echo '```'
  } >> "$GITHUB_STEP_SUMMARY"
fi
