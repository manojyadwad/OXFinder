#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# OxyssFileExplorer Standalone App Bundle & DMG Build Script
# ==============================================================================

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${PROJECT_DIR}/build"
APP_NAME="OX Finder"
BIN_NAME="OXFinder"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
DMG_PATH="${BUILD_DIR}/${APP_NAME}.dmg"
STAGING_DIR="${BUILD_DIR}/dmg_staging"

echo "==> Step 1: Compiling ${BIN_NAME} in Release mode..."
cd "${PROJECT_DIR}"
swift build -c release

RELEASE_BIN="$(swift build -c release --show-bin-path)/${BIN_NAME}"

echo "==> Step 2: Assembling macOS App Bundle..."
rm -rf "${APP_BUNDLE}" "${STAGING_DIR}" "${DMG_PATH}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

# Copy binary
cp "${RELEASE_BIN}" "${MACOS_DIR}/${BIN_NAME}"
chmod +x "${MACOS_DIR}/${BIN_NAME}"

# Copy Info.plist & PkgInfo
cp "${PROJECT_DIR}/Resources/Info.plist" "${CONTENTS_DIR}/Info.plist"
echo "APPL????" > "${CONTENTS_DIR}/PkgInfo"

# Copy App Icons
if [ -f "${PROJECT_DIR}/Resources/AppIcon.icns" ]; then
    cp "${PROJECT_DIR}/Resources/AppIcon.icns" "${RESOURCES_DIR}/AppIcon.icns"
fi
if [ -f "${PROJECT_DIR}/Resources/AppIcon.png" ]; then
    cp "${PROJECT_DIR}/Resources/AppIcon.png" "${RESOURCES_DIR}/AppIcon.png"
fi

echo "==> Step 3: Code Signing..."
# Check for Apple Developer ID identity
DEVELOPER_ID=$(security find-identity -v -p codesigning | grep "Developer ID Application:" | head -n 1 | awk -F'"' '{print $2}' || true)

if [ -n "${DEVELOPER_ID}" ]; then
    echo "Found Developer ID: ${DEVELOPER_ID}"
    codesign --force --deep --options runtime \
        --entitlements "${PROJECT_DIR}/Resources/FileExplorer.entitlements" \
        --sign "${DEVELOPER_ID}" \
        "${APP_BUNDLE}"
else
    echo "No Developer ID certificate found. Performing ad-hoc code signing..."
    codesign --force --deep \
        --entitlements "${PROJECT_DIR}/Resources/FileExplorer.entitlements" \
        --sign - \
        "${APP_BUNDLE}"
fi

codesign --verify --deep --strict --verbose=2 "${APP_BUNDLE}"

echo "==> Step 4: Packaging DMG..."
mkdir -p "${STAGING_DIR}"
cp -R "${APP_BUNDLE}" "${STAGING_DIR}/"

# Create /Applications symlink for drag-and-drop installer
ln -s /Applications "${STAGING_DIR}/Applications"

# Create compressed DMG
hdiutil create -volname "${APP_NAME}" \
    -srcfolder "${STAGING_DIR}" \
    -ov -format UDZO \
    "${DMG_PATH}"

# Clean up staging
rm -rf "${STAGING_DIR}"

echo "=============================================================================="
echo " BUILD SUCCESSFUL!"
echo " App Bundle: ${APP_BUNDLE}"
echo " DMG Image:  ${DMG_PATH}"
echo "=============================================================================="
echo ""
echo "To notarize for direct distribution outside the Mac App Store:"
echo "  xcrun notarytool submit ${DMG_PATH} --keychain-profile \"AC_PASSWORD\" --wait"
echo "  xcrun stapler staple ${DMG_PATH}"
echo "=============================================================================="
