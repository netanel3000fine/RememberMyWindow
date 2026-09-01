#!/usr/bin/env bash
set -euo pipefail

# dmg.sh - Build the app and package it into a shareable DMG

APP_NAME="RememberMyWindows"
DMG_NAME="${APP_NAME}.dmg"
TEMP_DMG_DIR="temp_dmg"

cd "$(dirname "$0")"

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
    WindowLayout/ContentView.swift \
    WindowLayout/ThemeManager.swift \
    WindowLayout/WindowManager.swift \
    WindowLayout/ScreenFingerprint.swift \
    WindowLayout/WindowRecord.swift \
    WindowLayout/LayoutsView.swift \
    WindowLayout/ActivityView.swift \
    WindowLayout/SettingsView.swift \
    WindowLayout/WindowPreviewComponents.swift \
    WindowLayout/NotchNotification.swift \
    WindowLayout/DesktopToggleManager.swift \
    WindowLayout/Localization.swift \
    WindowLayout/OnboardingView.swift \
    WindowLayout/CommandOverlayManager.swift \
    WindowLayout/WebAppDetector.swift \
    WindowLayout/MenuBarIconManager.swift \
    -o "${MACOS_DIR}/${APP_NAME}"

echo "  - Generating Info.plist..."
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
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
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
if [ -f "WindowLayout/AppIcon.icns" ]; then
    cp "WindowLayout/AppIcon.icns" "${RESOURCES_DIR}/AppIcon.icns"
fi

echo "  - Copying localizations..."
if [ -d "WindowLayout/he.lproj" ]; then
    cp -R "WindowLayout/he.lproj" "${RESOURCES_DIR}/"
fi
if [ -d "WindowLayout/en.lproj" ]; then
    cp -R "WindowLayout/en.lproj" "${RESOURCES_DIR}/"
fi

echo "  - Copying bundled sounds..."
if [ -d "WindowLayout/Sounds" ]; then
    cp WindowLayout/Sounds/*.m4a "${RESOURCES_DIR}/" 2>/dev/null || true
fi

echo "  - Code signing (Ad-hoc with stable designated requirement)..."
codesign --force --deep --sign - -r="designated => identifier \"com.netanel.remembermywindows\"" --entitlements WindowLayout/RememberMyWindows.entitlements "${APP_DIR}"

echo "Step 2: Preparing DMG contents..."
rm -rf "$TEMP_DMG_DIR"
mkdir -p "$TEMP_DMG_DIR"

# Copy the app
cp -R "${APP_DIR}" "$TEMP_DMG_DIR/"

# Create symlink to /Applications
ln -s /Applications "$TEMP_DMG_DIR/Applications"

echo "Step 3: Creating DMG..."
rm -f "$DMG_NAME"
hdiutil create -volname "${APP_NAME}" -srcfolder "$TEMP_DMG_DIR" -ov -format UDZO "$DMG_NAME"

echo "Step 4: Cleanup..."
rm -rf "$TEMP_DMG_DIR"

echo "----------------------------------------------------"
echo "Success! Your shareable DMG is ready:"
echo "$(pwd)/${DMG_NAME}"
echo "----------------------------------------------------"
