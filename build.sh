#!/bin/bash
set -e

cd "$(dirname "$0")"

echo "Building MediaClip..."
swift build

echo "Creating app bundle..."
rm -rf build/MediaClip.app
APP_DIR="build/MediaClip.app/Contents"
mkdir -p "$APP_DIR/MacOS"
mkdir -p "$APP_DIR/Resources"

cp .build/debug/MediaClip "$APP_DIR/MacOS/MediaClip"

# Write resolved Info.plist (no Xcode build variables)
cat > "$APP_DIR/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>MediaClip</string>
    <key>CFBundleDisplayName</key>
    <string>MediaClip</string>
    <key>CFBundleIdentifier</key>
    <string>com.mediaclip.app</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleExecutable</key>
    <string>MediaClip</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>MediaClip needs Apple Events access to paste clipboard content into other applications.</string>
</dict>
</plist>
PLIST

# Copy entitlements
cp MediaClip/Resources/MediaClip.entitlements "$APP_DIR/Resources/"

# Ad-hoc code sign with entitlements
echo "Signing app bundle..."
codesign --force --sign - \
    --entitlements MediaClip/Resources/MediaClip.entitlements \
    --timestamp=none \
    --generate-entitlement-der \
    "build/MediaClip.app"

echo "Build complete! App bundle at: build/MediaClip.app"
echo ""
echo "To run: open build/MediaClip.app"
echo "Note: Grant Accessibility permission in System Settings > Privacy & Security > Accessibility"
echo ""
echo "macOS 15+ users: If blocked by Gatekeeper, run:"
echo "  xattr -cr build/MediaClip.app"
