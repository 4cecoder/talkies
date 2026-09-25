#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
LINUX_DIR="${REPOSITORY_ROOT}/linux"
VERSION="${VERSION:?Set VERSION to the release label (for example v0.1.0 or ci-123)}"
APP_VERSION="${APP_VERSION:?Set APP_VERSION to a numeric version (for example 0.1.0)}"
OUTPUT_DIR="${OUTPUT_DIR:-${LINUX_DIR}/dist}"
WHISPER_BUILD_DIR="${WHISPER_BUILD_DIR:-/tmp/whisper.cpp/build}"
WHISPER_LICENSE="${WHISPER_LICENSE:-/tmp/whisper.cpp/LICENSE}"
LLAMA_LIBRARY_DIR="${LLAMA_LIBRARY_DIR:-/usr/local/lib}"
LLAMA_LICENSE="${LLAMA_LICENSE:-/tmp/llama.cpp/LICENSE}"

if [[ ! "${APP_VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "APP_VERSION must be MAJOR.MINOR.PATCH; got ${APP_VERSION}" >&2
    exit 1
fi

for required_file in \
    "${LINUX_DIR}/zig-out/bin/talkies" \
    "${LINUX_DIR}/talkies-overlay-gtk" \
    "${WHISPER_LICENSE}" \
    "${LLAMA_LICENSE}"; do
    if [[ ! -f "${required_file}" ]]; then
        echo "Required release input is missing: ${required_file}" >&2
        exit 1
    fi
done

mkdir -p "${OUTPUT_DIR}"
STAGING_DIR="$(mktemp -d)"
SMOKE_DIR="$(mktemp -d)"
trap 'rm -rf "${STAGING_DIR}" "${SMOKE_DIR}"' EXIT

PACKAGE_DIR="${STAGING_DIR}/talkies-linux"
mkdir -p "${PACKAGE_DIR}/lib" "${PACKAGE_DIR}/licenses"
install -m 0755 "${LINUX_DIR}/zig-out/bin/talkies" "${PACKAGE_DIR}/talkies"
install -m 0755 "${LINUX_DIR}/talkies-overlay-gtk" "${PACKAGE_DIR}/talkies-overlay-gtk"

# Bundle Talkies' pinned ASR and llama.cpp runtimes; distro libraries remain
# external dependencies and are listed in the Linux installation guide.
find "${WHISPER_BUILD_DIR}" -name 'lib*.so*' -exec cp -P -t "${PACKAGE_DIR}/lib" {} +
find "${LLAMA_LIBRARY_DIR}" -maxdepth 1 \( -name 'libllama.so*' -o -name 'libggml*.so*' \) \
    -exec cp -P -t "${PACKAGE_DIR}/lib" {} +
install -m 0644 "${WHISPER_LICENSE}" "${PACKAGE_DIR}/licenses/whisper.cpp-MIT.txt"
install -m 0644 "${LLAMA_LICENSE}" "${PACKAGE_DIR}/licenses/llama.cpp-MIT.txt"

shopt -s nullglob
whisper_libraries=("${PACKAGE_DIR}"/lib/libwhisper.so*)
llama_libraries=("${PACKAGE_DIR}"/lib/libllama.so*)
ggml_libraries=("${PACKAGE_DIR}"/lib/libggml*.so*)
shopt -u nullglob
if (( ${#whisper_libraries[@]} == 0 || ${#llama_libraries[@]} == 0 || ${#ggml_libraries[@]} == 0 )); then
    echo "Portable archive is missing a Whisper, llama, or ggml runtime library." >&2
    exit 1
fi

ARCHIVE="${OUTPUT_DIR}/Talkies-Linux-${VERSION}.tar.gz"
tar -czf "${ARCHIVE}" -C "${STAGING_DIR}" talkies-linux
tar -xzf "${ARCHIVE}" -C "${SMOKE_DIR}"
EXTRACTED_DIR="${SMOKE_DIR}/talkies-linux"
test -x "${EXTRACTED_DIR}/talkies"
test -x "${EXTRACTED_DIR}/talkies-overlay-gtk"
test -s "${EXTRACTED_DIR}/licenses/whisper.cpp-MIT.txt"
test -s "${EXTRACTED_DIR}/licenses/llama.cpp-MIT.txt"

if ldd "${EXTRACTED_DIR}/talkies" | grep -F 'not found'; then
    echo "Portable Talkies binary has unresolved shared-library dependencies." >&2
    exit 1
fi
LD_LIBRARY_PATH="${EXTRACTED_DIR}/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}" \
    "${EXTRACTED_DIR}/talkies" --help >/dev/null

# Debian/Ubuntu package: keep the real binary beside its private libraries so
# its $ORIGIN/lib rpath remains valid, and expose stable commands in /usr/bin.
DEB_ROOT="${STAGING_DIR}/deb-root"
install -d "${DEB_ROOT}/usr/lib/talkies" "${DEB_ROOT}/usr/bin" "${DEB_ROOT}/DEBIAN"
cp -a "${PACKAGE_DIR}/." "${DEB_ROOT}/usr/lib/talkies/"
ln -s ../lib/talkies/talkies "${DEB_ROOT}/usr/bin/talkies"
ln -s ../lib/talkies/talkies-overlay-gtk "${DEB_ROOT}/usr/bin/talkies-overlay-gtk"

SHLIBS_DEPENDS="$(dpkg-shlibdeps -O -l"${DEB_ROOT}/usr/lib/talkies/lib" \
    -e"${DEB_ROOT}/usr/lib/talkies/talkies" | sed -n 's/^shlibs:Depends=//p')"
if [[ -z "${SHLIBS_DEPENDS}" ]]; then
    echo "Could not determine the Linux runtime library dependencies." >&2
    exit 1
fi
cat > "${DEB_ROOT}/DEBIAN/control" <<EOF
Package: talkies
Version: ${APP_VERSION}
Section: sound
Priority: optional
Architecture: amd64
Depends: ${SHLIBS_DEPENDS}, python3, python3-gi, gir1.2-gtk-4.0
Maintainer: Talkies contributors <opensource@talkies.app>
Description: Offline voice transcription for Linux
 Talkies records speech and transcribes it locally. Model files are stored in
 the user's data directory and can be downloaded once for offline use.
EOF

DEB="${OUTPUT_DIR}/Talkies-Linux-${VERSION}.deb"
dpkg-deb --build --root-owner-group "${DEB_ROOT}" "${DEB}"
dpkg-deb --info "${DEB}" >/dev/null
dpkg-deb --extract "${DEB}" "${SMOKE_DIR}/deb"
test -x "${SMOKE_DIR}/deb/usr/lib/talkies/talkies"
test -L "${SMOKE_DIR}/deb/usr/bin/talkies"
test -s "${SMOKE_DIR}/deb/usr/lib/talkies/licenses/whisper.cpp-MIT.txt"
test -s "${SMOKE_DIR}/deb/usr/lib/talkies/licenses/llama.cpp-MIT.txt"
if ldd "${SMOKE_DIR}/deb/usr/lib/talkies/talkies" | grep -F 'not found'; then
    echo "Debian Talkies binary has unresolved shared-library dependencies." >&2
    exit 1
fi
LD_LIBRARY_PATH="${SMOKE_DIR}/deb/usr/lib/talkies/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}" \
    "${SMOKE_DIR}/deb/usr/lib/talkies/talkies" --help >/dev/null

echo "Created and smoke-tested ${ARCHIVE} and ${DEB}"
