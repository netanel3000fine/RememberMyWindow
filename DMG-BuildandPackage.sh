#!/usr/bin/env bash
set -euo pipefail

# DMG-BuildandPackage.sh
# Builds the app and packages it into a premium custom-styled DMG installer.

APP_NAME="RememberMyWindows"
DMG_NAME="${APP_NAME}.dmg"
ZIP_NAME="${APP_NAME}.zip"
BG_IMAGE="WindowLayout/DMGBackground.tiff"

cd "$(dirname "$0")"

# ──────────────────────────────────────────────
# Step 1: Build the app
# ──────────────────────────────────────────────
echo "Step 1: Building a fresh version of the app..."

APP_DIR="${APP_NAME}.app"
MACOS_DIR="${APP_DIR}/Contents/MacOS"
RESOURCES_DIR="${APP_DIR}/Contents/Resources"

mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

echo "  - Compiling Swift files..."
swiftc -parse-as-library \
    -sdk "$(xcrun --show-sdk-path --sdk macosx)" \
    -target "arm64-apple-macosx14.0" \
    WindowLayout/RememberMyWindowsApp.swift \
    WindowLayout/UpdateManager.swift \
    WindowLayout/ContentView.swift \
    WindowLayout/ThemeManager.swift \
    WindowLayout/WindowManager.swift \
    WindowLayout/ScreenFingerprint.swift \
    WindowLayout/WindowSpaces.swift \
    WindowLayout/WindowRecord.swift \
    WindowLayout/AutoSaveStore.swift \
    WindowLayout/AutoLayoutHeroCard.swift \
    WindowLayout/LayoutsView.swift \
    WindowLayout/ActivityView.swift \
    WindowLayout/SettingsView.swift \
    WindowLayout/WindowPreviewComponents.swift \
    WindowLayout/NotchShapes.swift \
    WindowLayout/NotchNotification.swift \
    WindowLayout/NotchWelcomePillView.swift \
    WindowLayout/DesktopToggleManager.swift \
    WindowLayout/Hotkey.swift \
    WindowLayout/ShortcutMigrationView.swift \
    WindowLayout/Localization.swift \
    WindowLayout/OnboardingView.swift \
    WindowLayout/WhatsNewView.swift \
    WindowLayout/CommandOverlayManager.swift \
    WindowLayout/WebAppDetector.swift \
    WindowLayout/MenuBarIconManager.swift \
    WindowLayout/VorssaintNotchCoordinator.swift \
    -o "${MACOS_DIR}/${APP_NAME}"

APP_VERSION=$(grep -E '^## \[[vV]?[0-9]+(\.[0-9]+)*\]' CHANGELOG.md | head -n 1 | sed -E 's/.*\[[vV]?([^]]+)\].*/\1/' || echo "13.1")

echo "  - Generating Info.plist for v${APP_VERSION}..."
cat <<EOF > "${APP_DIR}/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>com.netanel.remembermywindows</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleVersion</key>
    <string>${APP_VERSION}</string>
    <key>CFBundleShortVersionString</key>
    <string>${APP_VERSION}</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>RememberMyWindows needs permission to move windows in other apps.</string>
    <key>NSAccessibilityUsageDescription</key>
    <string>RememberMyWindows needs Accessibility access to restore window positions in other apps.</string>
    <key>NSLocationWhenInUseUsageDescription</key>
    <string>RememberMyWindows captures your location when saving layouts to help you remember where they were created. The coordinates are sent to Apple to look up the address.</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLName</key>
            <string>remembermywindows</string>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>remembermywindows</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
EOF

echo "  - Copying icon..."
[ -f "WindowLayout/AppIcon.icns" ] && cp "WindowLayout/AppIcon.icns" "${RESOURCES_DIR}/AppIcon.icns"
[ -f "WindowLayout/AppIcon.png"  ] && cp "WindowLayout/AppIcon.png"  "${RESOURCES_DIR}/AppIcon.png"
[ -f "WindowLayout/VorssaintAppIcon.png" ] && cp "WindowLayout/VorssaintAppIcon.png" "${RESOURCES_DIR}/VorssaintAppIcon.png"
[ -f "WindowLayout/MenuDropdownPreview.png" ] && cp "WindowLayout/MenuDropdownPreview.png" "${RESOURCES_DIR}/MenuDropdownPreview.png"

echo "  - Copying localizations..."
[ -d "WindowLayout/he.lproj" ] && cp -R "WindowLayout/he.lproj" "${RESOURCES_DIR}/"
[ -d "WindowLayout/en.lproj" ] && cp -R "WindowLayout/en.lproj" "${RESOURCES_DIR}/"

echo "  - Copying bundled sounds..."
[ -d "WindowLayout/Sounds" ] && cp WindowLayout/Sounds/*.m4a "${RESOURCES_DIR}/" 2>/dev/null || true

echo "  - Copying bundled wallpapers..."
[ -f "WindowLayout/DesktopWallpaper.jpg" ] && cp "WindowLayout/DesktopWallpaper.jpg" "${RESOURCES_DIR}/DesktopWallpaper.jpg"

echo "  - Code signing..."
codesign --force --deep --sign - \
  -r="designated => identifier \"com.netanel.remembermywindows\"" \
  --entitlements WindowLayout/RememberMyWindows.entitlements \
  "${APP_DIR}"

# ──────────────────────────────────────────────
# Step 2: ZIP for update channel
# ──────────────────────────────────────────────
echo ""
echo "Step 2: Creating ZIP update package..."
rm -f "$ZIP_NAME"
ditto -c -k --sequesterRsrc --keepParent "${APP_DIR}" "$ZIP_NAME"

# ──────────────────────────────────────────────
# Step 3: Build the DMG with create-dmg
# ──────────────────────────────────────────────
echo ""
echo "Step 3: Building premium styled DMG..."

rm -f "$DMG_NAME"

# create-dmg handles:
#   - Icon sizes and positions
#   - Window size and styling
#   - Read-only UDZO conversion
create-dmg \
  --volname "${APP_NAME}" \
  --volicon "WindowLayout/AppIcon.icns" \
  --background "${BG_IMAGE}" \
  --window-pos 400 250 \
  --window-size 600 360 \
  --text-size 12 \
  --icon-size 128 \
  --icon "${APP_NAME}.app" 160 180 \
  --hide-extension "${APP_NAME}.app" \
  --app-drop-link 440 180 \
  --no-internet-enable \
  "${DMG_NAME}" \
  "${APP_NAME}.app"

echo ""
echo "────────────────────────────────────────────"
echo "✅ Success! Premium DMG is ready:"
echo "   $(pwd)/${DMG_NAME}"
echo "────────────────────────────────────────────"
