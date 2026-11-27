#!/bin/bash
# Builds Headroom and installs it to /Applications (the menu bar needs it there: macOS 27 files menu bar items
# of apps outside /Applications by program path, and menu bar managers then can't place them).
# Usage: scripts/install.sh [--login-item]   (--login-item also starts Headroom when you log in)
set -euo pipefail
cd "$(dirname "$0")/.."
app="/Applications/Headroom.app"
./scripts/build.sh
pkill -x Headroom 2>/dev/null || true
for _ in $(seq 1 50); do pgrep -x Headroom >/dev/null || break; sleep 0.1; done
rm -rf "$app.new"
ditto build/Headroom.app "$app.new"   # copy to a temp name first so a failed copy never leaves you without the app
rm -rf "$app"
mv "$app.new" "$app"
if [ "${1:-}" = "--login-item" ]; then
  uid=$(id -u); plist="$HOME/Library/LaunchAgents/io.github.jasherjoshuachan.headroom.plist"
  mkdir -p "$HOME/Library/LaunchAgents"
  cat > "$plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>io.github.jasherjoshuachan.headroom</string>
    <key>ProgramArguments</key><array><string>/usr/bin/open</string><string>-g</string><string>$app</string></array>
    <key>RunAtLoad</key><true/>
</dict>
</plist>
PLIST
  launchctl bootout "gui/$uid/io.github.jasherjoshuachan.headroom" 2>/dev/null || true
  launchctl bootstrap "gui/$uid" "$plist"
else
  open -g "$app"
fi
rm -f "${HEADROOM_CACHE_DIR:-$HOME/.cache/headroom}"/*.json 2>/dev/null || true
echo "Headroom $(tr -d '[:space:]' < VERSION) installed in $app"
