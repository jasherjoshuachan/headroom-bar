#!/bin/bash
# Builds build/Headroom.app from app/main.swift. Needs the Xcode Command Line Tools (swiftc).
# Usage: scripts/build.sh [--zip]   (--zip also writes dist/Headroom-<version>.zip and its .sha256)
set -euo pipefail
cd "$(dirname "$0")/.."
version="$(tr -d '[:space:]' < VERSION)"
app="build/Headroom.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
swiftc -O app/main.swift -o "$app/Contents/MacOS/Headroom"
cp -R providers "$app/Contents/Resources/providers"
find "$app/Contents/Resources/providers" -name __pycache__ -prune -exec rm -rf {} +
cp config/accounts.example.json "$app/Contents/Resources/accounts.example.json"
cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key><string>io.github.jasherjoshuachan.headroom</string>
    <key>CFBundleName</key><string>Headroom</string>
    <key>CFBundleDisplayName</key><string>Headroom</string>
    <key>CFBundleExecutable</key><string>Headroom</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${version}</string>
    <key>CFBundleVersion</key><string>${version}</string>
    <key>LSUIElement</key><true/>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
</dict>
</plist>
PLIST
# Ad-hoc signature (no Apple Developer ID yet): macOS will ask you to confirm the first open. See README.
codesign --force --sign - --identifier io.github.jasherjoshuachan.headroom "$app" >/dev/null
echo "built $app ($version)"
if [ "${1:-}" = "--zip" ]; then
  mkdir -p dist
  zip="dist/Headroom-${version}.zip"
  rm -f "$zip"
  ditto -c -k --keepParent "$app" "$zip"
  (cd dist && shasum -a 256 "Headroom-${version}.zip" > "Headroom-${version}.zip.sha256")
  echo "wrote $zip"
fi
