#!/bin/bash
set -e

cd "$(dirname "$0")"

VERSION="${1:-1.0.0}"
echo "=== MediaClip v${VERSION} Release Build ==="

# 1. Build optimized binary
echo "[1/4] Building release binary..."
swift build -c release

# 2. Create app bundle
echo "[2/4] Creating app bundle..."
APP_DIR="build/MediaClip.app/Contents"
rm -rf build/MediaClip.app
mkdir -p "$APP_DIR/MacOS"
mkdir -p "$APP_DIR/Resources"

cp .build/release/MediaClip "$APP_DIR/MacOS/MediaClip"

cat > "$APP_DIR/Info.plist" << PLIST
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
    <string>${VERSION}</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
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
echo "[2.5/4] Signing app bundle..."
codesign --force --sign - \
    --entitlements MediaClip/Resources/MediaClip.entitlements \
    --timestamp=none \
    --generate-entitlement-der \
    "build/MediaClip.app"

echo "  Signature: $(codesign -d --verbose=1 build/MediaClip.app 2>&1 | grep 'Signature')"

# 3. Create DMG
echo "[3/4] Creating DMG..."
DMG_NAME="MediaClip-v${VERSION}.dmg"
rm -rf build/dmg_staging
mkdir -p build/dmg_staging
cp -R build/MediaClip.app build/dmg_staging/
ln -s /Applications build/dmg_staging/Applications

# Add install helper script for macOS 15+ Gatekeeper bypass
cat > build/dmg_staging/Install.command << 'INSTALL_SCRIPT'
#!/bin/bash
# MediaClip Installer
# macOS 15 Sequoia+ ではダウンロードしたアプリの起動に追加手順が必要です。
# このスクリプトがインストールと Gatekeeper 設定を自動で行います。

set -e

echo ""
echo "=== MediaClip インストーラー ==="
echo ""

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_SRC="$SCRIPT_DIR/MediaClip.app"
APP_DST="/Applications/MediaClip.app"

if [ ! -d "$APP_SRC" ]; then
    echo "エラー: MediaClip.app が見つかりません。"
    echo "DMG を開いた状態でこのスクリプトを実行してください。"
    exit 1
fi

# Stop running instance if exists
pkill -x MediaClip 2>/dev/null && sleep 1 || true

echo "MediaClip.app を /Applications にコピーしています..."
cp -R "$APP_SRC" "$APP_DST"

echo "Gatekeeper 属性を解除しています..."
xattr -cr "$APP_DST"

echo ""
echo "インストール完了！MediaClip を起動します..."
echo ""
echo "※ 初回起動時に「アクセシビリティ」の許可が求められます。"
echo "  システム設定 > プライバシーとセキュリティ > アクセシビリティ"
echo "  で MediaClip を許可してください。"
echo ""

open "$APP_DST"
INSTALL_SCRIPT
chmod +x build/dmg_staging/Install.command

rm -f "build/${DMG_NAME}"
hdiutil create \
    -volname "MediaClip" \
    -srcfolder build/dmg_staging \
    -ov \
    -format UDZO \
    "build/${DMG_NAME}"

rm -rf build/dmg_staging

# 4. Done
echo "[4/4] Done!"
echo ""
echo "Output: build/${DMG_NAME}"
echo "Size: $(du -h "build/${DMG_NAME}" | cut -f1)"
echo ""
echo "To create a GitHub release:"
echo "  gh release create v${VERSION} build/${DMG_NAME} --title \"MediaClip v${VERSION}\" --notes-file RELEASE_NOTES.md"
