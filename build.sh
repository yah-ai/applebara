#!/usr/bin/env bash
# Build Applebara.app from main.swift + assets/icon.png
# Usage:
#   ./build.sh                                  # ad-hoc signature (local use)
#   IDENTITY="Developer ID Application: …" ./build.sh   # signed for distribution
set -euo pipefail
cd "$(dirname "$0")"

NAME="Applebara"
APP="$NAME.app"
IDENTITY="${IDENTITY:--}"          # "-" == ad-hoc

echo "▸ icon → icns"
rm -rf "$APP" "$NAME.iconset" "$NAME.icns"
mkdir -p "$NAME.iconset"
for s in 16 32 128 256 512; do
  d=$((s * 2))
  sips -z "$s" "$s" assets/icon.png --out "$NAME.iconset/icon_${s}x${s}.png"    >/dev/null
  sips -z "$d" "$d" assets/icon.png --out "$NAME.iconset/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$NAME.iconset" -o "$NAME.icns"
rm -rf "$NAME.iconset"

echo "▸ compile"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swiftc -O -o "$APP/Contents/MacOS/$NAME" main.swift
cp "$NAME.icns" "$APP/Contents/Resources/$NAME.icns"
cp assets/menubar.png "$APP/Contents/Resources/menubar.png"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>$NAME</string>
  <key>CFBundleDisplayName</key><string>$NAME</string>
  <key>CFBundleIdentifier</key><string>dev.yah.applebara</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleExecutable</key><string>$NAME</string>
  <key>CFBundleIconFile</key><string>$NAME</string>
  <key>LSUIElement</key><true/>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
</dict></plist>
PLIST

echo "▸ sign ($IDENTITY)"
if [ "$IDENTITY" = "-" ]; then
  codesign --force -s - "$APP"
else
  codesign --force --options runtime --timestamp -s "$IDENTITY" "$APP"
fi

rm -f "$NAME.icns"
echo "✓ built $APP"
