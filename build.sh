#!/bin/bash
set -e

APP_NAME="CommandMove"
BUILD_DIR="build"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
CONTENTS="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS}/MacOS"
RESOURCES_DIR="${CONTENTS}/Resources"

echo "Building ${APP_NAME}..."

# Clean
rm -rf "${BUILD_DIR}"

# Create app bundle structure
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

# Copy Info.plist
cp Resources/Info.plist "${CONTENTS}/Info.plist"

# Copy icon
cp Resources/AppIcon.icns "${RESOURCES_DIR}/AppIcon.icns"

# Copy entitlements
cp Resources/CommandMove.entitlements "${BUILD_DIR}/${APP_NAME}.entitlements"

# Detect architecture
ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
    TARGET="arm64-apple-macosx13.0"
else
    TARGET="x86_64-apple-macosx13.0"
fi

# Compile Swift sources
echo "Compiling Swift sources for ${ARCH}..."
swiftc \
    -o "${MACOS_DIR}/${APP_NAME}" \
    -framework Cocoa \
    -framework Carbon \
    -framework UserNotifications \
    -framework ServiceManagement \
    -target "${TARGET}" \
    -O \
    Sources/main.swift \
    Sources/AppDelegate.swift \
    Sources/HotkeyManager.swift \
    Sources/FinderBridge.swift \
    Sources/FileCutPaste.swift

# Build the Finder Service (right-click context menu)
echo "Building Finder Service..."
SERVICE_BUNDLE="${CONTENTS}/Library/Services/Cut Files (CommandMove).app"
SERVICE_CONTENTS="${SERVICE_BUNDLE}/Contents"
SERVICE_MACOS="${SERVICE_CONTENTS}/MacOS"
mkdir -p "${SERVICE_MACOS}"
cp Resources/ServiceInfo.plist "${SERVICE_CONTENTS}/Info.plist"
swiftc \
    -o "${SERVICE_MACOS}/CutFiles" \
    -framework Cocoa \
    -target "${TARGET}" \
    -O \
    Sources/Service/main.swift

# Ad-hoc code sign (required for Accessibility + AppleScript on modern macOS)
echo "Code signing (ad-hoc)..."
codesign --force --sign - \
    "${SERVICE_BUNDLE}"
codesign --force --sign - \
    --entitlements "${BUILD_DIR}/${APP_NAME}.entitlements" \
    "${APP_BUNDLE}"

# Verify service bundle has Info.plist
echo "Verifying service bundle..."
ls -la "${SERVICE_CONTENTS}/Info.plist"
cat "${SERVICE_CONTENTS}/Info.plist" | head -5

# Install service to ~/Library/Services/ for discovery
echo "Installing service to ~/Library/Services/..."
mkdir -p ~/Library/Services/
rm -rf ~/Library/Services/"Cut Files (CommandMove).app"
cp -R "${SERVICE_BUNDLE}" ~/Library/Services/
echo "Service installed."

# Create DMG
DMG_NAME="${APP_NAME}.dmg"
DMG_PATH="${BUILD_DIR}/${DMG_NAME}"
DMG_TEMP="${BUILD_DIR}/dmg-staging"

echo "Creating DMG..."
rm -rf "${DMG_TEMP}"
mkdir -p "${DMG_TEMP}"

# Copy app into staging
cp -R "${APP_BUNDLE}" "${DMG_TEMP}/"

# Create Applications symlink for drag-and-drop install
ln -s /Applications "${DMG_TEMP}/Applications"

# Remove old DMG if exists
rm -f "${DMG_PATH}"

# Create DMG (read/write first, then convert to compressed)
hdiutil create \
    -srcfolder "${DMG_TEMP}" \
    -volname "${APP_NAME}" \
    -fs APFS \
    -format UDRW \
    "${BUILD_DIR}/${APP_NAME}-tmp.dmg"

# Convert to compressed read-only
hdiutil convert \
    "${BUILD_DIR}/${APP_NAME}-tmp.dmg" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "${DMG_PATH}"

rm -f "${BUILD_DIR}/${APP_NAME}-tmp.dmg"
rm -rf "${DMG_TEMP}"

# Get DMG size
DMG_SIZE=$(ls -lh "${DMG_PATH}" | awk '{print $5}')

echo ""
echo "============================================"
echo "  BUILD COMPLETE"
echo "============================================"
echo ""
echo "  App:     ${APP_BUNDLE}"
echo "  DMG:     ${DMG_PATH} (${DMG_SIZE})"
echo ""
echo "  To install:"
echo "    open ${DMG_PATH}"
echo "    Drag CommandMove to Applications"
echo ""
echo "  FIRST TIME SETUP REQUIRED"
echo "  1. macOS will prompt for Accessibility access."
echo "     System Settings > Privacy & Security > Accessibility"
echo "     Enable CommandMove"
echo ""
echo "  2. macOS may also prompt for Automation access"
echo "     to control Finder. Click Allow."
echo ""
echo "  3. Use Cmd+X to cut, Cmd+V to paste (move)."
echo "============================================"
