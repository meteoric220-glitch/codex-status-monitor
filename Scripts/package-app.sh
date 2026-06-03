#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build"
APP_DIR="$ROOT_DIR/Packaging/Codex Status Monitor.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

rm -rf "$BUILD_DIR/release/CodexStatusMonitor_CodexStatusMonitor.bundle"
swift build --scratch-path "$BUILD_DIR" --configuration release --product CodexStatusMonitor

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$BUILD_DIR/release/CodexStatusMonitor" "$MACOS_DIR/Codex Status Monitor"
cp -R "$BUILD_DIR/release/CodexStatusMonitor_CodexStatusMonitor.bundle" "$APP_DIR/CodexStatusMonitor_CodexStatusMonitor.bundle"
cp "$ROOT_DIR/Sources/CodexStatusMonitor/Resources/lobe-codex.png" "$RESOURCES_DIR/lobe-codex.png"
cp "$ROOT_DIR/Sources/CodexStatusMonitor/Resources/lobe-claude.png" "$RESOURCES_DIR/lobe-claude.png"
cp "$ROOT_DIR/Sources/CodexStatusMonitor/Resources/LobeIcons-LICENSE.txt" "$RESOURCES_DIR/LobeIcons-LICENSE.txt"

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>Codex Status Monitor</string>
  <key>CFBundleIdentifier</key>
  <string>dev.local.codex-status-monitor</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>Codex Status Monitor</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

echo "Packaged: $APP_DIR"
