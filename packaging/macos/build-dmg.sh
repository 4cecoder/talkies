#!/bin/bash

################################################################################
# Talkies macOS DMG Build Script
#
# This script automates the complete process of building a distributable DMG
# for the Talkies Swift/SwiftUI application, including:
# - Building release version
# - Creating .app bundle structure
# - Code signing (optional)
# - DMG creation with Applications symlink
# - Notarization (optional)
#
# Usage:
#   ./build-dmg.sh                    # Full build with signing
#   SKIP_SIGNING=1 ./build-dmg.sh     # Build without signing (testing)
#   NOTARIZE=1 ./build-dmg.sh         # Build with notarization
################################################################################

set -e  # Exit on error
set -u  # Exit on undefined variable

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
APP_NAME="Talkies"
VERSION="${VERSION:-1.0.0}"
BUNDLE_ID="com.talkies.app"
MIN_MACOS_VERSION="15.0"

# Paths (relative to script location)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../mac" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/build"
DMG_OUTPUT_DIR="${SCRIPT_DIR}"

# Code signing (update these with your actual values)
SIGNING_IDENTITY="${SIGNING_IDENTITY:-Developer ID Application: Your Name (TEAMID)}"
NOTARY_PROFILE="${NOTARY_PROFILE:-talkies-notary-profile}"

# Options
SKIP_SIGNING="${SKIP_SIGNING:-0}"
NOTARIZE="${NOTARIZE:-0}"

################################################################################
# Helper Functions
################################################################################

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_command() {
    if ! command -v "$1" &> /dev/null; then
        log_error "Required command '$1' not found. Please install it first."
        exit 1
    fi
}

################################################################################
# Preflight Checks
################################################################################

log_info "Starting Talkies DMG build process..."

# Check required commands
check_command swift
check_command hdiutil

# Check for create-dmg (optional but recommended)
if command -v create-dmg &> /dev/null; then
    USE_CREATE_DMG=1
    log_info "Using create-dmg for DMG creation"
else
    USE_CREATE_DMG=0
    log_warning "create-dmg not found, will use hdiutil (install with: brew install create-dmg)"
fi

# Check for signing identity if not skipping
if [ "$SKIP_SIGNING" == "0" ]; then
    if ! security find-identity -v -p codesigning | grep -q "$SIGNING_IDENTITY"; then
        log_warning "Signing identity '$SIGNING_IDENTITY' not found in keychain"
        log_warning "Set SKIP_SIGNING=1 to build unsigned DMG for testing"
        log_error "Either install certificate or skip signing"
        exit 1
    fi
    log_success "Found signing identity: $SIGNING_IDENTITY"
fi

################################################################################
# Clean and Setup Build Directory
################################################################################

log_info "Setting up build directory..."

rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
APP_CONTENTS="${APP_BUNDLE}/Contents"
APP_MACOS="${APP_CONTENTS}/MacOS"
APP_RESOURCES="${APP_CONTENTS}/Resources"

################################################################################
# Build Release Binary
################################################################################

log_info "Building ${APP_NAME} in release mode..."

cd "${PROJECT_ROOT}"

swift build -c release --arch arm64 --arch x86_64 2>&1 | tee "${BUILD_DIR}/build.log" || {
    log_error "Swift build failed. Check ${BUILD_DIR}/build.log for details."
    exit 1
}

log_success "Build completed successfully"

# Note: Swift Package Manager doesn't support universal binaries directly
# For now, build for current architecture. For universal binary, use xcodebuild
BINARY_PATH="${PROJECT_ROOT}/.build/release/${APP_NAME}"

if [ ! -f "${BINARY_PATH}" ]; then
    log_error "Binary not found at ${BINARY_PATH}"
    exit 1
fi

################################################################################
# Create .app Bundle Structure
################################################################################

log_info "Creating application bundle structure..."

mkdir -p "${APP_MACOS}"
mkdir -p "${APP_RESOURCES}"

# Copy binary
cp "${BINARY_PATH}" "${APP_MACOS}/${APP_NAME}"
chmod +x "${APP_MACOS}/${APP_NAME}"

log_success "Copied binary to app bundle"

################################################################################
# Create Info.plist
################################################################################

log_info "Generating Info.plist..."

cat > "${APP_CONTENTS}/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>LSMinimumSystemVersion</key>
    <string>${MIN_MACOS_VERSION}</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSUIElement</key>
    <true/>
    <key>NSMicrophoneUsageDescription</key>
    <string>Talkies needs access to your microphone for voice transcription.</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>Talkies needs to control other applications to insert transcribed text.</string>
</dict>
</plist>
EOF

log_success "Created Info.plist"

################################################################################
# Add Application Icon (if available)
################################################################################

ICON_SOURCE="${PROJECT_ROOT}/Resources/AppIcon.icns"
if [ -f "${ICON_SOURCE}" ]; then
    log_info "Adding application icon..."
    cp "${ICON_SOURCE}" "${APP_RESOURCES}/AppIcon.icns"

    # Update Info.plist to reference icon
    /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon.icns" "${APP_CONTENTS}/Info.plist" 2>/dev/null || true
    log_success "Added application icon"
else
    log_warning "No icon found at ${ICON_SOURCE}, skipping"
fi

################################################################################
# Create Entitlements (for signing)
################################################################################

if [ "$SKIP_SIGNING" == "0" ]; then
    log_info "Creating entitlements file..."

    ENTITLEMENTS="${BUILD_DIR}/${APP_NAME}.entitlements"

    cat > "${ENTITLEMENTS}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Required for Hardened Runtime -->
    <key>com.apple.security.cs.allow-jit</key>
    <true/>

    <!-- Audio recording permission -->
    <key>com.apple.security.device.audio-input</key>
    <true/>

    <!-- Network access for LLM plugins -->
    <key>com.apple.security.network.client</key>
    <true/>

    <!-- Disable library validation for third-party libraries -->
    <key>com.apple.security.cs.disable-library-validation</key>
    <true/>

    <!-- Allow unsigned executable memory (if needed by WhisperKit) -->
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <true/>
</dict>
</plist>
EOF

    log_success "Created entitlements file"
fi

################################################################################
# Code Sign Application
################################################################################

if [ "$SKIP_SIGNING" == "0" ]; then
    log_info "Code signing application bundle..."

    # Remove any extended attributes first
    xattr -cr "${APP_BUNDLE}" 2>/dev/null || true

    # Sign the app
    codesign \
        --deep \
        --force \
        --verify \
        --verbose \
        --sign "${SIGNING_IDENTITY}" \
        --options runtime \
        --entitlements "${ENTITLEMENTS}" \
        "${APP_BUNDLE}"

    log_success "Application signed successfully"

    # Verify signature
    log_info "Verifying signature..."
    codesign --verify --verbose=4 "${APP_BUNDLE}"
    log_success "Signature verified"
else
    log_warning "Skipping code signing (SKIP_SIGNING=1)"
fi

################################################################################
# Create DMG
################################################################################

DMG_NAME="${APP_NAME}-${VERSION}.dmg"
DMG_PATH="${DMG_OUTPUT_DIR}/${DMG_NAME}"

log_info "Creating DMG: ${DMG_NAME}..."

# Remove old DMG if exists
rm -f "${DMG_PATH}"

if [ "$USE_CREATE_DMG" == "1" ]; then
    # Use create-dmg for professional appearance
    log_info "Using create-dmg for DMG creation..."

    # Check if background image exists
    BACKGROUND_IMG="${SCRIPT_DIR}/dmg-background.png"
    BACKGROUND_OPTION=""
    if [ -f "${BACKGROUND_IMG}" ]; then
        BACKGROUND_OPTION="--background ${BACKGROUND_IMG}"
    fi

    create-dmg \
        --volname "${APP_NAME}" \
        --window-pos 200 120 \
        --window-size 800 400 \
        --icon-size 100 \
        --icon "${APP_NAME}.app" 200 190 \
        --hide-extension "${APP_NAME}.app" \
        --app-drop-link 600 185 \
        ${BACKGROUND_OPTION} \
        "${DMG_PATH}" \
        "${APP_BUNDLE}" \
        2>&1 | tee "${BUILD_DIR}/dmg.log" || {
        log_error "create-dmg failed. Check ${BUILD_DIR}/dmg.log"
        exit 1
    }
else
    # Fallback to hdiutil
    log_info "Using hdiutil for DMG creation..."

    TEMP_DMG="${BUILD_DIR}/temp.dmg"
    MOUNT_POINT="/Volumes/${APP_NAME}"

    # Create temporary DMG
    hdiutil create -size 200m -fs HFS+J -volname "${APP_NAME}" "${TEMP_DMG}"

    # Mount it
    hdiutil attach "${TEMP_DMG}" -mountpoint "${MOUNT_POINT}"

    # Copy app
    cp -R "${APP_BUNDLE}" "${MOUNT_POINT}/"

    # Create Applications symlink
    ln -s /Applications "${MOUNT_POINT}/Applications"

    # Unmount
    hdiutil detach "${MOUNT_POINT}"

    # Convert to compressed, read-only DMG
    hdiutil convert "${TEMP_DMG}" -format UDZO -o "${DMG_PATH}"

    # Cleanup
    rm "${TEMP_DMG}"
fi

log_success "DMG created: ${DMG_PATH}"

################################################################################
# Sign DMG
################################################################################

if [ "$SKIP_SIGNING" == "0" ]; then
    log_info "Signing DMG..."

    codesign --sign "${SIGNING_IDENTITY}" "${DMG_PATH}"

    log_success "DMG signed successfully"

    # Verify DMG signature
    log_info "Verifying DMG signature..."
    codesign --verify --verbose=4 "${DMG_PATH}"
    log_success "DMG signature verified"
else
    log_warning "Skipping DMG signing (SKIP_SIGNING=1)"
fi

################################################################################
# Notarization (Optional)
################################################################################

if [ "$NOTARIZE" == "1" ]; then
    if [ "$SKIP_SIGNING" == "1" ]; then
        log_error "Cannot notarize unsigned DMG. Remove SKIP_SIGNING=1"
        exit 1
    fi

    log_info "Submitting DMG for notarization..."
    log_warning "This may take 5-60 minutes..."

    # Submit for notarization
    SUBMISSION_OUTPUT=$(xcrun notarytool submit "${DMG_PATH}" \
        --keychain-profile "${NOTARY_PROFILE}" \
        --wait 2>&1)

    echo "${SUBMISSION_OUTPUT}"

    if echo "${SUBMISSION_OUTPUT}" | grep -q "status: Accepted"; then
        log_success "Notarization accepted!"

        # Extract submission ID for stapling
        SUBMISSION_ID=$(echo "${SUBMISSION_OUTPUT}" | grep "id:" | head -1 | awk '{print $2}')

        log_info "Stapling notarization ticket to DMG..."
        xcrun stapler staple "${DMG_PATH}"

        log_success "Notarization ticket stapled"

        # Verify stapling
        log_info "Verifying stapled ticket..."
        xcrun stapler validate "${DMG_PATH}"

        # Verify Gatekeeper acceptance
        log_info "Verifying Gatekeeper acceptance..."
        spctl -a -t open --context context:primary-signature -v "${DMG_PATH}"

        log_success "DMG is fully notarized and ready for distribution!"
    else
        log_error "Notarization failed or rejected"
        log_info "Check logs with: xcrun notarytool log <submission-id> --keychain-profile ${NOTARY_PROFILE}"
        exit 1
    fi
else
    log_info "Skipping notarization (set NOTARIZE=1 to enable)"
fi

################################################################################
# Final Summary
################################################################################

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_success "Build completed successfully!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  App Bundle:    ${APP_BUNDLE}"
echo "  DMG:           ${DMG_PATH}"
echo "  Version:       ${VERSION}"
echo "  Signed:        $([ "$SKIP_SIGNING" == "0" ] && echo "Yes" || echo "No")"
echo "  Notarized:     $([ "$NOTARIZE" == "1" ] && echo "Yes" || echo "No")"
echo ""

if [ "$SKIP_SIGNING" == "1" ]; then
    log_warning "DMG is UNSIGNED - only for testing, not for distribution!"
    echo ""
fi

if [ "$SKIP_SIGNING" == "0" ] && [ "$NOTARIZE" == "0" ]; then
    log_info "Next steps:"
    echo "  1. Test the DMG on a clean macOS system"
    echo "  2. When ready, notarize with: NOTARIZE=1 ./build-dmg.sh"
    echo "  3. Distribute via your website or GitHub Releases"
    echo ""
fi

log_info "Build artifacts saved to: ${BUILD_DIR}"
log_info "DMG ready for distribution: ${DMG_PATH}"
echo ""
