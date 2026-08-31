#!/usr/bin/env bash
set -euo pipefail

# Reset all permissions for the app to start "fresh" every build
# This automates the "minus" button in System Settings
echo "Quitting existing app..."
pkill -x "RememberMyWindows" || true

# Reset onboarding state so splash screens always appear on each dev build.
# NOTE: TCC permissions (Accessibility) are NOT reset here — they persist across builds
#       thanks to the stable designated requirement (identifier "com.netanel.remembermywindows").
echo "Resetting onboarding state for dev build..."
defaults delete com.netanel.remembermywindows hasCompletedOnboarding 2>/dev/null || true

# Reset Device Control and Data Access TCC permission for the old build
# (disables the toggle shown in System Settings → Privacy → Device Control and Data Access)
echo "Resetting Device Control and Data Access permission..."
tccutil reset DeviceControl com.netanel.remembermywindows 2>/dev/null || true

cd "$(dirname "$0")"

APP_NAME="RememberMyWindows"
APP_DIR="${APP_NAME}.app"
MACOS_DIR="${APP_DIR}/Contents/MacOS"
RESOURCES_DIR="${APP_DIR}/Contents/Resources"
MODULE_CACHE_DIR="${TMPDIR:-/tmp}/RememberMyWindows-module-cache"

# Keep Clang's generated Swift module cache in a writable temporary location.
# The default user cache can be unavailable in sandboxed shells, which otherwise
# makes Swift report misleading SDK/module compatibility errors.
mkdir -p "$MODULE_CACHE_DIR"
export CLANG_MODULE_CACHE_PATH="$MODULE_CACHE_DIR"

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
    WindowLayout/Hotkey.swift \
    WindowLayout/ShortcutMigrationView.swift \
    WindowLayout/Localization.swift \
    WindowLayout/OnboardingView.swift \
    WindowLayout/CommandOverlayManager.swift \
    WindowLayout/WebAppDetector.swift \
    WindowLayout/MenuBarIconManager.swift \
    -o "${MACOS_DIR}/${APP_NAME}"

APP_VERSION=$(grep -E '^## \[[vV]?[0-9]+(\.[0-9]+)*\]' CHANGELOG.md | head -n 1 | sed -E 's/.*\[[vV]?([^]]+)\].*/\1/' || echo "13.1")

echo "Generating Info.plist for v${APP_VERSION}..."
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
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleLocalizations</key>
    <array>
        <string>en</string>
        <string>he</string>
    </array>
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
    <string>RememberMyWindows captures your location when saving layouts to help you remember where they were created.</string>
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

echo "Copying icon..."
cp "WindowLayout/AppIcon.icns" "${RESOURCES_DIR}/AppIcon.icns"

echo "Copying localizations..."
if [ -d "WindowLayout/he.lproj" ]; then
    cp -R "WindowLayout/he.lproj" "${RESOURCES_DIR}/"
fi
if [ -d "WindowLayout/en.lproj" ]; then
    cp -R "WindowLayout/en.lproj" "${RESOURCES_DIR}/"
fi

echo "Copying bundled sounds..."
if [ -d "WindowLayout/Sounds" ]; then
    cp WindowLayout/Sounds/*.m4a "${RESOURCES_DIR}/" 2>/dev/null || true
fi

echo "Code signing (Ad-hoc with stable designated requirement)..."
codesign --force --deep --sign - -r="designated => identifier \"com.netanel.remembermywindows\"" --entitlements WindowLayout/RememberMyWindows.entitlements "${APP_DIR}"

# Remove any legacy duplicate app bundle from parent directory if present
if [ -d "../${APP_NAME}.app" ]; then
    rm -rf "../${APP_NAME}.app"
fi

echo "Done! App built in ${APP_DIR}"

echo "Launching app..."
open "${APP_DIR}"
