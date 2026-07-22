#!/usr/bin/env bash
# Build Applebara.app and install it to /Applications, replacing any running copy.
# Usage:
#   ./install.sh                 # build, then install
#   SKIP_BUILD=1 ./install.sh    # install the Applebara.app already in this dir
set -euo pipefail
cd "$(dirname "$0")"

NAME="Applebara"
APP="$NAME.app"
DEST="/Applications/$APP"

# Do NOT run under sudo: the app would land owned by root, and the ⌘Space toggle
# writes com.apple.symbolichotkeys in the *calling user's* preferences.
if [ "$(id -u)" -eq 0 ]; then
  echo "error: don't run this with sudo — /Applications is admin-writable already." >&2
  exit 1
fi

if [ "${SKIP_BUILD:-}" = "1" ]; then
  [ -d "$APP" ] || { echo "error: no $APP here; drop SKIP_BUILD to build it." >&2; exit 1; }
else
  ./build.sh
fi

echo "▸ quitting any running $NAME"
pkill -x "$NAME" 2>/dev/null || true   # non-zero when it isn't running; that's fine

echo "▸ installing → $DEST"
rm -rf "$DEST"
cp -R "$APP" "$DEST"

echo "▸ launching"
open "$DEST"
echo "✓ installed $DEST"
echo "  Menu bar → \"Use ⌘Space (replaces Spotlight)\" to take over ⌘Space."
echo "  System Settings → General → Login Items to start it at login."
