#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
MAC_PACKAGE="${REPOSITORY_ROOT}/mac"
VERSION="${VERSION:-0.0.0}"
BUNDLE_VERSION="${VERSION#v}"
OUTPUT_DIR="${OUTPUT_DIR:-${SCRIPT_DIR}/dist}"
APP_NAME="Talkies"
APP_BUNDLE="${OUTPUT_DIR}/${APP_NAME}.app"

(cd "${MAC_PACKAGE}" && swift build -c release)
BIN_DIR="$(cd "${MAC_PACKAGE}" && swift build -c release --show-bin-path)"
EXECUTABLE="${BIN_DIR}/${APP_NAME}"
LLAMA_FRAMEWORK="${BIN_DIR}/llama.framework"

if [[ ! -x "${EXECUTABLE}" ]]; then
    echo "Missing release executable: ${EXECUTABLE}" >&2
    exit 1
fi

if [[ ! -d "${LLAMA_FRAMEWORK}" ]]; then
    echo "Missing llama runtime framework: ${LLAMA_FRAMEWORK}" >&2
    exit 1
fi

rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS" "${APP_BUNDLE}/Contents/Frameworks"
ditto "${EXECUTABLE}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
ditto "${LLAMA_FRAMEWORK}" "${APP_BUNDLE}/Contents/Frameworks/llama.framework"
ditto "${SCRIPT_DIR}/Info.plist.template" "${APP_BUNDLE}/Contents/Info.plist"

PLIST="${APP_BUNDLE}/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${BUNDLE_VERSION}" "${PLIST}"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${BUNDLE_VERSION}" "${PLIST}"

EXECUTABLE_PATH="${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
if ! otool -l "${EXECUTABLE_PATH}" | grep -Fq '@loader_path/../Frameworks'; then
    install_name_tool -add_rpath '@loader_path/../Frameworks' "${EXECUTABLE_PATH}"
fi

plutil -lint "${PLIST}"
otool -L "${EXECUTABLE_PATH}" | grep -Fq '@rpath/llama.framework/Versions/Current/llama'
otool -l "${EXECUTABLE_PATH}" | grep -Fq '@loader_path/../Frameworks'
test -x "${EXECUTABLE_PATH}"
test -f "${APP_BUNDLE}/Contents/Frameworks/llama.framework/Versions/Current/llama"

mkdir -p "${OUTPUT_DIR}"
ZIP_PATH="${OUTPUT_DIR}/${APP_NAME}-macOS-${VERSION}.zip"
rm -f "${ZIP_PATH}"
ditto -c -k --sequesterRsrc --keepParent "${APP_BUNDLE}" "${ZIP_PATH}"
echo "Created ${ZIP_PATH}"
