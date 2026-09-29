#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ARCH="${1:-$(uname -m)}"
case "$ARCH" in
    arm64|x86_64|universal) ;;
    *) echo "Usage: $0 [arm64|x86_64|universal]" >&2; exit 2 ;;
esac
BUILD_ROOT="$SCRIPT_DIR/.build/$ARCH"
APP_NAME="Talkies-Monterey-12.7.6-$ARCH"
OUTPUT_DIR="$SCRIPT_DIR/dist"
APP="$OUTPUT_DIR/$APP_NAME.app"

test -x "$BUILD_ROOT/app-bin/TalkiesMonterey" || { echo "Run build.sh $ARCH first." >&2; exit 1; }
if [[ "$ARCH" == "universal" ]]; then
    PACKAGE_ARCHES=(arm64 x86_64)
else
    PACKAGE_ARCHES=("$ARCH")
fi
for target_arch in "${PACKAGE_ARCHES[@]}"; do
    test -x "$BUILD_ROOT/engines/whisper-cli-$target_arch" || { echo "Run build.sh $ARCH first." >&2; exit 1; }
    test -x "$BUILD_ROOT/engines/llama-completion-$target_arch"
done

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Helpers" "$APP/Contents/Resources/Legal/ThirdParty"
cp "$SCRIPT_DIR/Info.plist" "$APP/Contents/Info.plist"
cp "$BUILD_ROOT/app-bin/TalkiesMonterey" "$APP/Contents/MacOS/TalkiesMonterey"
for target_arch in "${PACKAGE_ARCHES[@]}"; do
    cp "$BUILD_ROOT/engines/whisper-cli-$target_arch" "$APP/Contents/Helpers/whisper-cli-$target_arch"
    cp "$BUILD_ROOT/engines/llama-completion-$target_arch" "$APP/Contents/Helpers/llama-completion-$target_arch"
done
cp "$REPO_ROOT/branding/icons/talkies-app-icon.icns" "$APP/Contents/Resources/talkies-app-icon.icns"
cp "$REPO_ROOT/mobile/android/third_party/whisper.cpp/LICENSE" "$APP/Contents/Resources/Legal/ThirdParty/whisper.cpp-LICENSE.txt"
cp "$REPO_ROOT/mobile/android/third_party/llama.cpp/LICENSE" "$APP/Contents/Resources/Legal/ThirdParty/llama.cpp-LICENSE.txt"

cat > "$APP/Contents/Resources/Legal/ThirdParty/NOTICE.txt" <<'EOF'
Talkies Monterey preview contains whisper.cpp and llama.cpp under their MIT licenses.
The Whisper base model and Superwhisper S1-mini model are downloaded to the user's
Application Support folder after explicit use. Their license and notice files are
downloaded alongside the S1-mini model. No model weights are included in this app.
EOF

submodule_revision() {
    git -C "$1" rev-parse HEAD 2>/dev/null || echo unavailable
}
{
    echo "Talkies Monterey preview: 0.1.0"
    echo "Minimum macOS: 12.0 (test requested on 12.7.6)"
    echo "Apple silicon uses Metal with CPU fallback; Intel uses CPU. Model weights are downloaded separately."
    echo "whisper.cpp: $(submodule_revision "$REPO_ROOT/mobile/android/third_party/whisper.cpp")"
    echo "llama.cpp: $(submodule_revision "$REPO_ROOT/mobile/android/third_party/llama.cpp")"
} > "$APP/Contents/Resources/BUILD-INFO.txt"

for target_arch in "${PACKAGE_ARCHES[@]}"; do
    codesign --force --sign - "$APP/Contents/Helpers/whisper-cli-$target_arch"
    codesign --force --sign - "$APP/Contents/Helpers/llama-completion-$target_arch"
done
codesign --force --deep --sign - "$APP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$OUTPUT_DIR/$APP_NAME.zip"
shasum -a 256 "$OUTPUT_DIR/$APP_NAME.zip" > "$OUTPUT_DIR/$APP_NAME.zip.sha256"

echo "Created $OUTPUT_DIR/$APP_NAME.zip"
