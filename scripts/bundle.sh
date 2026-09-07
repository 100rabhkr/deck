#!/usr/bin/env bash
# Build an unsigned (ad-hoc signed) Deck.app you can double-click.
# Signing/notarising for distribution needs full Xcode + an Apple Developer ID;
# this produces a locally-runnable bundle (first launch: right-click > Open).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/dist/Deck.app"
BIN="Deck"
BUNDLE_ID="com.saurabhkumar.deck"
VERSION="0.1.0"

echo "Building DeckApp (release)..."
swift build -c release --product DeckApp

echo "Assembling $APP ..."
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$ROOT/.build/release/DeckApp" "$APP/Contents/MacOS/$BIN"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Deck</string>
    <key>CFBundleDisplayName</key><string>Deck</string>
    <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
    <key>CFBundleExecutable</key><string>${BIN}</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSDownloadsFolderUsageDescription</key><string>Deck opens terminals in your project folders, which may live in Downloads.</string>
    <key>NSDocumentsFolderUsageDescription</key><string>Deck opens terminals in your project folders.</string>
    <key>NSDesktopFolderUsageDescription</key><string>Deck opens terminals in your project folders.</string>
</dict>
</plist>
PLIST

# Ad-hoc code signature so macOS will run it (no Developer ID needed).
codesign --force --deep --sign - "$APP" 2>/dev/null || true

echo "Done: $APP"
echo "First launch: right-click the app > Open (Gatekeeper prompt), once."
