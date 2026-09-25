#!/usr/bin/env bash
set -euo pipefail

APP_BUNDLE="${APP_BUNDLE:-}"
RELEASE_LABEL="${RELEASE_LABEL:-}"
OUTPUT_DIR="${OUTPUT_DIR:-}"

if [[ -z "${APP_BUNDLE}" || -z "${RELEASE_LABEL}" || -z "${OUTPUT_DIR}" ]]; then
    echo "APP_BUNDLE, RELEASE_LABEL, and OUTPUT_DIR are required." >&2
    exit 2
fi
if [[ ! "${RELEASE_LABEL}" =~ ^(v?[0-9]+\.[0-9]+\.[0-9]+|latest|ci-[0-9]+)$ ]]; then
    echo "Invalid release label: ${RELEASE_LABEL}" >&2
    exit 2
fi
if [[ ! -d "${APP_BUNDLE}" || ! -x "${APP_BUNDLE}/Contents/MacOS/Talkies" ]]; then
    echo "Not a complete Talkies app bundle: ${APP_BUNDLE}" >&2
    exit 1
fi

mkdir -p "${OUTPUT_DIR}"
OUTPUT_DMG="${OUTPUT_DIR}/Talkies-macOS-${RELEASE_LABEL}.dmg"
TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/talkies-dmg.XXXXXX")"
TEMP_DMG="${OUTPUT_DMG}.tmp.$$.dmg"
STAGING_DIR="${TEMP_DIR}/Talkies"
MOUNT_POINT="${TEMP_DIR}/mounted"
ATTACHED=0

cleanup() {
    if [[ "${ATTACHED}" == "1" ]]; then
        hdiutil detach "${MOUNT_POINT}" -quiet || true
    fi
    rm -f "${TEMP_DMG}"
    rm -rf "${TEMP_DIR}"
}
trap cleanup EXIT

mkdir -p "${STAGING_DIR}" "${MOUNT_POINT}"
ditto "${APP_BUNDLE}" "${STAGING_DIR}/Talkies.app"
ln -s /Applications "${STAGING_DIR}/Applications"

hdiutil create -quiet -volname Talkies -srcfolder "${STAGING_DIR}" -format UDZO "${TEMP_DMG}"
hdiutil verify -quiet "${TEMP_DMG}"
hdiutil attach -quiet -readonly -nobrowse -mountpoint "${MOUNT_POINT}" "${TEMP_DMG}"
ATTACHED=1

MOUNTED_APP="${MOUNT_POINT}/Talkies.app"
test -x "${MOUNTED_APP}/Contents/MacOS/Talkies"
test -s "${MOUNTED_APP}/Contents/Resources/Talkies.icns"
test -f "${MOUNTED_APP}/Contents/Frameworks/llama.framework/Versions/Current/llama"
test -L "${MOUNT_POINT}/Applications"
plutil -lint "${MOUNTED_APP}/Contents/Info.plist" >/dev/null

# Exercise the documented drag-install and replacement-upgrade operations in an
# isolated Applications directory; never write to the runner's real /Applications.
INSTALL_ROOT="${TEMP_DIR}/install/Applications"
INSTALLED_APP="${INSTALL_ROOT}/Talkies.app"
UPGRADE_APP="${TEMP_DIR}/Talkies.app.upgrade"
PREVIOUS_APP="${TEMP_DIR}/Talkies.app.previous"
USER_CONFIG="${TEMP_DIR}/user-data/config/talkies"
USER_MODELS="${TEMP_DIR}/user-data/data/talkies/Models"
mkdir -p "${INSTALL_ROOT}"
mkdir -p "${USER_CONFIG}" "${USER_MODELS}"
printf 'preserve-config\n' > "${USER_CONFIG}/ci-preservation-check"
printf 'preserve-model\n' > "${USER_MODELS}/ci-preservation-check"
ditto "${MOUNTED_APP}" "${INSTALLED_APP}"
test -x "${INSTALLED_APP}/Contents/MacOS/Talkies"
test -f "${INSTALLED_APP}/Contents/Frameworks/llama.framework/Versions/Current/llama"

touch "${INSTALLED_APP}/Contents/Resources/old-install-sentinel"
ditto "${MOUNTED_APP}" "${UPGRADE_APP}"
mv "${INSTALLED_APP}" "${PREVIOUS_APP}"
mv "${UPGRADE_APP}" "${INSTALLED_APP}"
test ! -e "${INSTALLED_APP}/Contents/Resources/old-install-sentinel"
test -x "${INSTALLED_APP}/Contents/MacOS/Talkies"
test -f "${INSTALLED_APP}/Contents/Frameworks/llama.framework/Versions/Current/llama"
grep -Fx 'preserve-config' "${USER_CONFIG}/ci-preservation-check"
grep -Fx 'preserve-model' "${USER_MODELS}/ci-preservation-check"

# Drag-install removal is just removing the app bundle. Assert that user data
# outside Applications remains intact after uninstalling in the isolated test.
rm -rf "${INSTALLED_APP}"
test ! -e "${INSTALLED_APP}"
grep -Fx 'preserve-config' "${USER_CONFIG}/ci-preservation-check"
grep -Fx 'preserve-model' "${USER_MODELS}/ci-preservation-check"

hdiutil detach "${MOUNT_POINT}" -quiet
ATTACHED=0
mv -f "${TEMP_DMG}" "${OUTPUT_DMG}"
echo "Created and verified ${OUTPUT_DMG}"
