#!/usr/bin/env bash
# Notarize + staple a Developer ID-signed Applebara.app.
# Prereq (run ONCE, interactive — stores an app-specific password in your keychain):
#   xcrun notarytool store-credentials applebara-notary \
#     --apple-id human@yah.dev --team-id 7BW4R8G8Q6 --password <app-specific-password>
# Generate the app-specific password at https://appleid.apple.com → Sign-In & Security.
set -euo pipefail
cd "$(dirname "$0")/.."

# Do NOT run under sudo: notarytool reads the keychain profile from the *calling
# user's* login keychain, and root's keychain won't have it.
if [ "$(id -u)" -eq 0 ]; then
  echo "error: don't run this with sudo — notarytool needs your login keychain." >&2
  exit 1
fi

PROFILE="${PROFILE:-applebara-notary}"
if ! xcrun notarytool history --keychain-profile "$PROFILE" >/dev/null 2>&1; then
  echo "error: no notary profile '$PROFILE'. Run this first (no sudo):" >&2
  echo "  xcrun notarytool store-credentials $PROFILE \\" >&2
  echo "    --apple-id human@yah.dev --team-id 7BW4R8G8Q6" >&2
  exit 1
fi
ditto -c -k --keepParent Applebara.app dist/Applebara.zip
echo "▸ submitting to Apple notary…"
xcrun notarytool submit dist/Applebara.zip --keychain-profile "$PROFILE" --wait
echo "▸ stapling ticket…"
xcrun stapler staple Applebara.app
spctl -a -vv Applebara.app
# re-zip the stapled app for distribution
ditto -c -k --keepParent Applebara.app dist/Applebara.zip
echo "✓ notarized + stapled → dist/Applebara.zip"
