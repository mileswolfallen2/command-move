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
    TARGET="arm64-apple-macosx12.0"
else
    TARGET="x86_64-apple-macosx12.0"
fi

# Compile Swift sources
echo "Compiling Swift sources for ${ARCH}..."
swiftc \
    -o "${MACOS_DIR}/${APP_NAME}" \
    -framework Cocoa \
    -framework Carbon \
    -framework UserNotifications \
    -target "${TARGET}" \
    -O \
    Sources/main.swift \
    Sources/AppDelegate.swift \
    Sources/HotkeyManager.swift \
    Sources/FinderBridge.swift \
    Sources/FileCutPaste.swift

# Ad-hoc code sign (required for Accessibility + AppleScript on modern macOS)
echo "Code signing (ad-hoc)..."
codesign --force --sign - \
    --entitlements "${BUILD_DIR}/${APP_NAME}.entitlements" \
    "${APP_BUNDLE}"

echo ""
echo "Built: ${APP_BUNDLE}"
echo ""
echo "============================================"
echo "  FIRST TIME SETUP REQUIRED"
echo "============================================"
echo ""
echo "  1. Open the app:"
echo "     open ${APP_BUNDLE}"
echo ""
echo "  2. macOS will prompt for Accessibility access."
echo "     Go to: System Settings > Privacy & Security > Accessibility"
echo "     Enable the toggle for CommandMove"
echo ""
echo "  3. macOS may also prompt for Automation access"
echo "     to control Finder. Click Allow."
echo ""
echo "  4. Use Cmd+X to cut files, Cmd+V to paste (move) them."
echo "============================================"
