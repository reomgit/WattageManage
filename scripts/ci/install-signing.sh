#!/bin/bash
set -euo pipefail

# This changes the user keychain search list, so only run on ephemeral hosted CI.
if [[ "${GITHUB_ACTIONS:-}" != true || "${RUNNER_ENVIRONMENT:-}" != github-hosted ]]; then
  echo "Signing installation is restricted to GitHub-hosted Actions runners." >&2
  exit 1
fi
: "${RUNNER_TEMP:?Missing runner temporary directory}"
: "${GITHUB_ENV:?Missing Actions environment file}"
: "${BUILD_CERTIFICATE_BASE64:?Add the BUILD_CERTIFICATE_BASE64 repository secret}"
: "${P12_PASSWORD:?Add the P12_PASSWORD repository secret}"
: "${APP_PROVISION_PROFILE_BASE64:?Add the APP_PROVISION_PROFILE_BASE64 repository secret}"
: "${WIDGET_PROVISION_PROFILE_BASE64:?Add the WIDGET_PROVISION_PROFILE_BASE64 repository secret}"
: "${EXPORT_METHOD:?Select an export method}"

umask 077
SIGNING_DIR="$RUNNER_TEMP/wattage-signing"
SIGNING_KEYCHAIN_PATH="$RUNNER_TEMP/wattage-signing.keychain-db"
mkdir -p "$SIGNING_DIR"
printf '%s' "$BUILD_CERTIFICATE_BASE64" | base64 --decode > "$SIGNING_DIR/certificate.p12"
printf '%s' "$APP_PROVISION_PROFILE_BASE64" | base64 --decode > "$SIGNING_DIR/app.mobileprovision"
printf '%s' "$WIDGET_PROVISION_PROFILE_BASE64" | base64 --decode > "$SIGNING_DIR/widget.mobileprovision"

security cms -D -i "$SIGNING_DIR/app.mobileprovision" > "$SIGNING_DIR/app.plist"
security cms -D -i "$SIGNING_DIR/widget.mobileprovision" > "$SIGNING_DIR/widget.plist"
python3 "$(dirname "$0")/prepare-profiles.py"

KEYCHAIN_PASSWORD="$(openssl rand -hex 32)"
echo "::add-mask::$KEYCHAIN_PASSWORD"
security create-keychain -p "$KEYCHAIN_PASSWORD" "$SIGNING_KEYCHAIN_PATH"
security set-keychain-settings -lut 21600 "$SIGNING_KEYCHAIN_PATH"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$SIGNING_KEYCHAIN_PATH"
security import "$SIGNING_DIR/certificate.p12" -P "$P12_PASSWORD" -A -t cert -f pkcs12 -k "$SIGNING_KEYCHAIN_PATH"
security set-key-partition-list -S apple-tool:,apple:,codesign: -k "$KEYCHAIN_PASSWORD" "$SIGNING_KEYCHAIN_PATH" >/dev/null
security list-keychains -d user -s "$SIGNING_KEYCHAIN_PATH"
printf 'SIGNING_KEYCHAIN_PATH=%s\n' "$SIGNING_KEYCHAIN_PATH" >> "$GITHUB_ENV"
rm -f "$SIGNING_DIR/certificate.p12"
