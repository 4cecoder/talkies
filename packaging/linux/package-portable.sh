#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
LINUX_DIR="${REPOSITORY_ROOT}/linux"
VERSION="${VERSION:?Set VERSION to the release label (for example v0.1.0 or ci-123)}"
OUTPUT_DIR="${OUTPUT_DIR:-${LINUX_DIR}/dist}"
WHISPER_BUILD_DIR="${WHISPER_BUILD_DIR:-/tmp/whisper.cpp/build}"
WHISPER_LICENSE="${WHISPER_LICENSE:-/tmp/whisper.cpp/LICENSE}"
LLAMA_LIBRARY_DIR="${LLAMA_LIBRARY_DIR:-/usr/local/lib}"
LLAMA_LICENSE="${LLAMA_LICENSE:-/tmp/llama.cpp/LICENSE}"

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

echo "Created and smoke-tested ${ARCHIVE}"
