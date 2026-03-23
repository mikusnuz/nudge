#!/bin/bash
set -e

# Config
APP_NAME="Nudge"
BUNDLE_ID="app.nudge.Nudge"
TEAM_ID="REDACTED"
IDENTITY="Developer ID Application: REDACTED (REDACTED)"
APPLE_ID="REDACTED"
APP_SPECIFIC_PASSWORD="REDACTED"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"
DMG_DIR="$BUILD_DIR/dmg"
APP_PATH="$BUILD_DIR/$APP_NAME.app"
DMG_PATH="$BUILD_DIR/$APP_NAME.dmg"

# Clean
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "==> Building $APP_NAME..."
xcodebuild -project "$PROJECT_DIR/Nudge.xcodeproj" \
  -scheme Nudge \
  -configuration Release \
  -derivedDataPath "$BUILD_DIR/DerivedData" \
  CODE_SIGN_IDENTITY="$IDENTITY" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  CODE_SIGN_STYLE=Manual \
  ENABLE_HARDENED_RUNTIME=YES \
  OTHER_CODE_SIGN_FLAGS="--options runtime --timestamp" \
  CODE_SIGN_ENTITLEMENTS="$PROJECT_DIR/Nudge/App/Nudge.entitlements" \
  -quiet

# Copy app
cp -R "$BUILD_DIR/DerivedData/Build/Products/Release/$APP_NAME.app" "$APP_PATH"

echo "==> Re-signing with hardened runtime (strip get-task-allow)..."
codesign --force --deep --sign "$IDENTITY" --options runtime --timestamp \
  --entitlements "$PROJECT_DIR/Nudge/App/Nudge.entitlements" \
  "$APP_PATH"

echo "==> Verifying code signature..."
codesign -dvv "$APP_PATH" 2>&1 | head -5
codesign --verify --deep --strict "$APP_PATH"
codesign -d --entitlements - "$APP_PATH" 2>&1 | grep -c "get-task-allow" && echo "    WARNING: get-task-allow still present!" || echo "    OK: no get-task-allow"

echo "==> Creating DMG..."
mkdir -p "$DMG_DIR"
cp -R "$APP_PATH" "$DMG_DIR/"
ln -s /Applications "$DMG_DIR/Applications"
hdiutil create -volname "$APP_NAME" -srcfolder "$DMG_DIR" -ov -format UDZO "$DMG_PATH"
rm -rf "$DMG_DIR"

echo "==> Signing DMG..."
codesign --sign "$IDENTITY" --timestamp "$DMG_PATH"

echo "==> Submitting for notarization..."
xcrun notarytool submit "$DMG_PATH" \
  --apple-id "$APPLE_ID" \
  --password "$APP_SPECIFIC_PASSWORD" \
  --team-id "$TEAM_ID" \
  --wait

echo "==> Stapling notarization ticket..."
xcrun stapler staple "$DMG_PATH"

echo ""
echo "==> Done! DMG ready at: $DMG_PATH"
echo "    Size: $(du -h "$DMG_PATH" | cut -f1)"
