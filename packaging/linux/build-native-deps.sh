#!/usr/bin/env bash
# Build the pinned llama.cpp + whisper.cpp runtimes that Talkies bundles.
#
# whisper.cpp is linked against llama.cpp's ggml (WHISPER_USE_SYSTEM_GGML)
# so the package ships exactly one libggml*: two copies with the same soname
# would silently shadow each other at runtime.
#
# GGML_NATIVE=OFF keeps the build portable: the default x86-64 feature set
# (AVX2/FMA/F16C) instead of the build machine's CPU.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=deps.env
source "${SCRIPT_DIR}/deps.env"

PREFIX="${PREFIX:-/usr/local}"
SRC_DIR="${SRC_DIR:-${TMPDIR:-/tmp}/talkies-native-src}"
JOBS="${JOBS:-$(nproc)}"
SUDO="${SUDO:-}"
if [[ -z "${SUDO}" && "$(id -u)" != 0 && ! -w "${PREFIX}" ]]; then SUDO=sudo; fi

fetch() { # <dir> <repo> <commit>
    if [[ ! -d "$1/.git" ]]; then git init -q "$1"; fi
    git -C "$1" fetch -q --depth=1 "$2" "$3"
    git -C "$1" checkout -q --detach FETCH_HEAD
}

mkdir -p "${SRC_DIR}"
fetch "${SRC_DIR}/llama.cpp" "${LLAMA_REPO}" "${LLAMA_COMMIT}"
fetch "${SRC_DIR}/whisper.cpp" "${WHISPER_REPO}" "${WHISPER_COMMIT}"

# shellcheck disable=SC2016 # $ORIGIN is for the dynamic loader, not the shell
common=(
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_INSTALL_PREFIX="${PREFIX}"
    -DCMAKE_INSTALL_LIBDIR=lib
    # Bundled libraries find each other (libwhisper -> libggml) beside
    # themselves, without LD_LIBRARY_PATH or a system-wide install.
    '-DCMAKE_INSTALL_RPATH=$ORIGIN'
    -DBUILD_SHARED_LIBS=ON
    -DGGML_NATIVE=OFF
    -DGGML_OPENMP=ON
    -DGGML_CUDA=OFF
    -DGGML_VULKAN=OFF
    -DGGML_METAL=OFF
)

cmake -S "${SRC_DIR}/llama.cpp" -B "${SRC_DIR}/llama.cpp/build" "${common[@]}" \
    -DLLAMA_CURL=OFF -DLLAMA_BUILD_COMMON=OFF -DLLAMA_BUILD_TESTS=OFF \
    -DLLAMA_BUILD_EXAMPLES=OFF -DLLAMA_BUILD_TOOLS=OFF -DLLAMA_BUILD_SERVER=OFF -DLLAMA_BUILD_APP=OFF
cmake --build "${SRC_DIR}/llama.cpp/build" --target llama -j "${JOBS}"
${SUDO} cmake --install "${SRC_DIR}/llama.cpp/build"

cmake -S "${SRC_DIR}/whisper.cpp" -B "${SRC_DIR}/whisper.cpp/build" "${common[@]}" \
    -DCMAKE_PREFIX_PATH="${PREFIX}" \
    -DWHISPER_USE_SYSTEM_GGML=ON \
    -DWHISPER_BUILD_TESTS=OFF -DWHISPER_BUILD_EXAMPLES=OFF -DWHISPER_BUILD_SERVER=OFF
cmake --build "${SRC_DIR}/whisper.cpp/build" -j "${JOBS}"
${SUDO} cmake --install "${SRC_DIR}/whisper.cpp/build"

if command -v ldconfig >/dev/null; then ${SUDO} ldconfig; fi
echo "Installed llama.cpp ${LLAMA_COMMIT:0:10} and whisper.cpp ${WHISPER_COMMIT:0:10} into ${PREFIX}"
