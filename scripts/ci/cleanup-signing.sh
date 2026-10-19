#!/bin/bash
set -euo pipefail

if [[ "${GITHUB_ACTIONS:-}" != true || "${RUNNER_ENVIRONMENT:-}" != github-hosted ]]; then
  echo "Signing cleanup is restricted to GitHub-hosted Actions runners." >&2
  exit 1
fi
: "${RUNNER_TEMP:?Missing runner temporary directory}"
KEYCHAIN_PATH="$RUNNER_TEMP/wattage-signing.keychain-db"
if [[ -f "$KEYCHAIN_PATH" ]]; then
  security delete-keychain "$KEYCHAIN_PATH" || true
fi
for UUID in "${WATTAGE_APP_PROFILE:-}" "${WATTAGE_WIDGET_PROFILE:-}"; do
  if [[ "$UUID" =~ ^[0-9a-fA-F-]{36}$ ]]; then
    rm -f "$HOME/Library/MobileDevice/Provisioning Profiles/$UUID.mobileprovision"
    rm -f "$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles/$UUID.mobileprovision"
  fi
done
rm -rf "$RUNNER_TEMP/wattage-signing"
