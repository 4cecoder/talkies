#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
MAC_PACKAGE="${REPOSITORY_ROOT}/mac"
VERSION="${VERSION:-0.0.0}"
BUNDLE_VERSION="${VERSION#v}"
OUTPUT_DIR="${OUTPUT_DIR:-${SCRIPT_DIR}/dist}"
SIGNING_IDENTITY="${SIGNING_IDENTITY:-}"
EXPECTED_TEAM_ID="${EXPECTED_TEAM_ID:-}"
SIGNING_ENABLED=1
APP_NAME="Talkies"
BUNDLE_ID="com.talkies.app"
FRAMEWORK_ID="org.ggml.llama"
APP_BUNDLE="${OUTPUT_DIR}/${APP_NAME}.app"

if [[ -z "${SIGNING_IDENTITY}" ]]; then
    if [[ "${GITHUB_ACTIONS:-}" == "true" && "${CI:-}" == "true" ]]; then
        # Public GitHub runners do not have a maintainer signing certificate.
        # CI validates packaging structure; local packaging remains fail-closed.
        SIGNING_ENABLED=0
        echo "GitHub Actions has no signing identity; creating an unsigned CI smoke artifact only."
    else
        echo "SIGNING_IDENTITY is required; refusing to create an ad-hoc signed Talkies package." >&2
        echo 'Set it to the persistent Apple Development identity, for example:' >&2
        echo '  SIGNING_IDENTITY="Apple Development: Name (TEAMID)" ./package-app.sh' >&2
        exit 1
    fi
else
    if [[ "${SIGNING_IDENTITY}" != "Apple Development: "* ]]; then
        echo "Expected an Apple Development signing identity, got: ${SIGNING_IDENTITY}" >&2
        exit 1
    fi

    if [[ -z "${EXPECTED_TEAM_ID}" ]]; then
        echo "EXPECTED_TEAM_ID is required; the identity name suffix is not necessarily Apple's Team ID." >&2
        exit 1
    fi

    VALID_IDENTITIES="$(security find-identity -v -p codesigning 2>/dev/null || true)"
    if ! grep -Fq "\"${SIGNING_IDENTITY}\"" <<<"${VALID_IDENTITIES}"; then
        echo "The requested signing identity is not currently valid: ${SIGNING_IDENTITY}" >&2
        exit 1
    fi
fi

verify_signed_code() {
    local code_path="$1"
    local expected_identifier="$2"
    local signature_details

    if ! codesign --verify --strict --verbose=2 "${code_path}"; then
        echo "Code signature verification failed: ${code_path}" >&2
        return 1
    fi

    signature_details="$(codesign -dv --verbose=4 "${code_path}" 2>&1)"
    if ! grep -Fqx "Identifier=${expected_identifier}" <<<"${signature_details}"; then
        echo "Unexpected code signature identifier for ${code_path}; expected ${expected_identifier}." >&2
        return 1
    fi
    if ! grep -Fqx "TeamIdentifier=${EXPECTED_TEAM_ID}" <<<"${signature_details}"; then
        echo "Unexpected or missing TeamIdentifier for ${code_path}; expected ${EXPECTED_TEAM_ID}." >&2
        return 1
    fi
    if grep -Fqx 'Signature=adhoc' <<<"${signature_details}"; then
        echo "Refusing ad-hoc signed code: ${code_path}" >&2
        return 1
    fi
    if ! grep -Fqx "Authority=${SIGNING_IDENTITY}" <<<"${signature_details}"; then
        echo "Code at ${code_path} was not signed by the requested identity: ${SIGNING_IDENTITY}" >&2
        return 1
    fi
}

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
mkdir -p "${APP_BUNDLE}/Contents/MacOS" "${APP_BUNDLE}/Contents/Frameworks" "${APP_BUNDLE}/Contents/Resources"
ditto "${EXECUTABLE}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
ditto "${LLAMA_FRAMEWORK}" "${APP_BUNDLE}/Contents/Frameworks/llama.framework"
ditto "${REPOSITORY_ROOT}/branding/icons/talkies-app-icon.icns" "${APP_BUNDLE}/Contents/Resources/Talkies.icns"
ditto "${SCRIPT_DIR}/Info.plist.template" "${APP_BUNDLE}/Contents/Info.plist"

PLIST="${APP_BUNDLE}/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${BUNDLE_VERSION}" "${PLIST}"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${BUNDLE_VERSION}" "${PLIST}"

EXECUTABLE_PATH="${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
if ! otool -l "${EXECUTABLE_PATH}" | grep -Fq '@loader_path/../Frameworks'; then
    install_name_tool -add_rpath '@loader_path/../Frameworks' "${EXECUTABLE_PATH}"
fi

if [[ "${SIGNING_ENABLED}" == "1" ]]; then
    # Sign nested code before the app so its resource seal covers the final
    # framework signature. Reuse one identity to preserve TCC across updates.
    echo "Signing Talkies and llama.framework with ${SIGNING_IDENTITY}"
    codesign --force --identifier "${FRAMEWORK_ID}" --sign "${SIGNING_IDENTITY}" --timestamp=none \
        "${APP_BUNDLE}/Contents/Frameworks/llama.framework"
    codesign --force --identifier "${BUNDLE_ID}" --sign "${SIGNING_IDENTITY}" --timestamp=none "${APP_BUNDLE}"
else
    echo "Skipping signing and TCC-signature validation for the GitHub Actions smoke artifact."
fi

plutil -lint "${PLIST}"
ACTUAL_BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "${PLIST}")"
ACTUAL_SHORT_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${PLIST}")"
ACTUAL_BUNDLE_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "${PLIST}")"
if [[ "${ACTUAL_BUNDLE_ID}" != "${BUNDLE_ID}" ]]; then
    echo "Unexpected bundle identifier: ${ACTUAL_BUNDLE_ID} (expected ${BUNDLE_ID})" >&2
    exit 1
fi
if [[ "${ACTUAL_SHORT_VERSION}" != "${BUNDLE_VERSION}" || "${ACTUAL_BUNDLE_VERSION}" != "${BUNDLE_VERSION}" ]]; then
    echo "Bundle version mismatch: short=${ACTUAL_SHORT_VERSION}, build=${ACTUAL_BUNDLE_VERSION}, expected=${BUNDLE_VERSION}" >&2
    exit 1
fi

otool -L "${EXECUTABLE_PATH}" | grep -Fq '@rpath/llama.framework/Versions/Current/llama'
otool -l "${EXECUTABLE_PATH}" | grep -Fq '@loader_path/../Frameworks'
test -x "${EXECUTABLE_PATH}"
test -s "${APP_BUNDLE}/Contents/Resources/Talkies.icns"
test -f "${APP_BUNDLE}/Contents/Frameworks/llama.framework/Versions/Current/llama"
FRAMEWORK_PLIST="${APP_BUNDLE}/Contents/Frameworks/llama.framework/Versions/Current/Resources/Info.plist"
if [[ ! -f "${FRAMEWORK_PLIST}" ]]; then
    echo "Missing llama.framework Info.plist: ${FRAMEWORK_PLIST}" >&2
    exit 1
fi
ACTUAL_FRAMEWORK_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "${FRAMEWORK_PLIST}")"
if [[ "${ACTUAL_FRAMEWORK_ID}" != "${FRAMEWORK_ID}" ]]; then
    echo "Unexpected llama.framework identifier: ${ACTUAL_FRAMEWORK_ID} (expected ${FRAMEWORK_ID})" >&2
    exit 1
fi

if [[ "${SIGNING_ENABLED}" == "1" ]]; then
    verify_signed_code "${APP_BUNDLE}/Contents/Frameworks/llama.framework" "${FRAMEWORK_ID}"
    verify_signed_code "${APP_BUNDLE}" "${BUNDLE_ID}"
    codesign --verify --deep --strict --verbose=2 "${APP_BUNDLE}"
fi

mkdir -p "${OUTPUT_DIR}"
ZIP_PATH="${OUTPUT_DIR}/${APP_NAME}-macOS-${VERSION}.zip"
ZIP_TMP="${ZIP_PATH}.tmp.$$"
trap 'rm -f "${ZIP_TMP}"' EXIT
ditto -c -k --sequesterRsrc --keepParent "${APP_BUNDLE}" "${ZIP_TMP}"
unzip -t "${ZIP_TMP}" >/dev/null
mv -f "${ZIP_TMP}" "${ZIP_PATH}"
trap - EXIT
echo "Created ${ZIP_PATH}"
