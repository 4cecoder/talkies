#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ARCH="${1:-$(uname -m)}"
case "$ARCH" in
    arm64|x86_64) BUILD_ARCHES=("$ARCH") ;;
    universal) BUILD_ARCHES=(arm64 x86_64) ;;
    *) echo "Usage: $0 [arm64|x86_64|universal]" >&2; exit 2 ;;
esac

BUILD_ROOT="$SCRIPT_DIR/.build/$ARCH"
ENGINE_DIR="$BUILD_ROOT/engines"
WHISPER_SOURCE="$REPO_ROOT/mobile/android/third_party/whisper.cpp"
LLAMA_SOURCE="$REPO_ROOT/mobile/android/third_party/llama.cpp"
DEPLOYMENT="12.0"

mkdir -p "$ENGINE_DIR"
for target_arch in "${BUILD_ARCHES[@]}"; do
    ARCH_ROOT="$BUILD_ROOT/$target_arch"
    if [[ "$target_arch" == "arm64" ]]; then
        METAL=ON
    else
        METAL=OFF
    fi
    common_cmake_args=(
        -DCMAKE_BUILD_TYPE=Release
        -DCMAKE_OSX_ARCHITECTURES="$target_arch"
        -DCMAKE_OSX_DEPLOYMENT_TARGET="$DEPLOYMENT"
        -DBUILD_SHARED_LIBS=OFF
        -DGGML_NATIVE=OFF
        -DGGML_METAL="$METAL"
        -DGGML_METAL_MACOSX_VERSION_MIN="$DEPLOYMENT"
        -DGGML_METAL_TARGET_OS=macos
        -DGGML_OPENMP=OFF
        -DGGML_BLAS=OFF
        -DGGML_LLAMAFILE=OFF
    )

    cmake -S "$WHISPER_SOURCE" -B "$ARCH_ROOT/whisper" \
        "${common_cmake_args[@]}" \
        -DWHISPER_BUILD_TESTS=OFF \
        -DWHISPER_BUILD_EXAMPLES=ON \
        -DWHISPER_BUILD_SERVER=OFF \
        -DWHISPER_CURL=OFF
    cmake --build "$ARCH_ROOT/whisper" --target whisper-cli --parallel

    cmake -S "$LLAMA_SOURCE" -B "$ARCH_ROOT/llama" \
        "${common_cmake_args[@]}" \
        -DLLAMA_BUILD_COMMON=ON \
        -DLLAMA_BUILD_TESTS=OFF \
        -DLLAMA_BUILD_TOOLS=ON \
        -DLLAMA_BUILD_EXAMPLES=OFF \
        -DLLAMA_BUILD_SERVER=OFF \
        -DLLAMA_BUILD_APP=OFF \
        -DLLAMA_BUILD_UI=OFF \
        -DLLAMA_OPENSSL=OFF
    cmake --build "$ARCH_ROOT/llama" --target llama-completion --parallel

    install -m 0755 "$ARCH_ROOT/whisper/bin/whisper-cli" "$ENGINE_DIR/whisper-cli-$target_arch"
    install -m 0755 "$ARCH_ROOT/llama/bin/llama-completion" "$ENGINE_DIR/llama-completion-$target_arch"
done

mkdir -p "$BUILD_ROOT/app-bin"
for target_arch in "${BUILD_ARCHES[@]}"; do
    swift build --package-path "$SCRIPT_DIR" -c release --triple "$target_arch-apple-macosx$DEPLOYMENT"
    mkdir -p "$BUILD_ROOT/app-bin/$target_arch"
    install -m 0755 "$SCRIPT_DIR/.build/$target_arch-apple-macosx/release/TalkiesMonterey" \
        "$BUILD_ROOT/app-bin/$target_arch/TalkiesMonterey"
done
if [[ "$ARCH" == "universal" ]]; then
    lipo -create "$BUILD_ROOT"/app-bin/{arm64,x86_64}/TalkiesMonterey -output "$BUILD_ROOT/app-bin/TalkiesMonterey"
else
    cp "$BUILD_ROOT/app-bin/$ARCH/TalkiesMonterey" "$BUILD_ROOT/app-bin/TalkiesMonterey"
fi

echo "Built Monterey engines and app executable for $ARCH under $BUILD_ROOT"
