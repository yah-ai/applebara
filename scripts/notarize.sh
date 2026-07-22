#!/usr/bin/env bash
# Notarize + staple a Developer ID-signed Applebara.app.
# Prereq (run ONCE, interactive — stores an app-specific password in your keychain):
#   xcrun notarytool store-credentials applebara-notary \
#     --apple-id human@yah.dev --team-id 7BW4R8G8Q6 --password <app-specific-password>
# Generate the app-specific password at https://appleid.apple.com → Sign-In & Security.
set -euo pipefail
cd "$(dirname "$0")/.."

PROFILE="${PROFILE:-applebara-notary}"
ditto -c -k --keepParent Applebara.app dist/Applebara.zip
echo "▸ submitting to Apple notary…"
xcrun notarytool submit dist/Applebara.zip --keychain-profile "$PROFILE" --wait
echo "▸ stapling ticket…"
xcrun stapler staple Applebara.app
spctl -a -vv Applebara.app
# re-zip the stapled app for distribution
ditto -c -k --keepParent Applebara.app dist/Applebara.zip
echo "✓ notarized + stapled → dist/Applebara.zip"
