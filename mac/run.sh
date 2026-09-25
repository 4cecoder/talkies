#!/bin/bash
# Run Talkies with Swift 6.3 or newer from the active toolchain.
SWIFT_BIN="${SWIFT_BIN:-$(command -v swift)}"

if [[ -z "$SWIFT_BIN" ]]; then
    echo "Swift 6.3 or newer is required. Install a toolchain and add swift to PATH." >&2
    exit 1
fi

SWIFT_VERSION=$("$SWIFT_BIN" --version | sed -n '1s/.*version \([0-9]*\.[0-9]*\).*/\1/p')
if [[ -z "$SWIFT_VERSION" ]] || [[ "$(printf '%s\n' 6.3 "$SWIFT_VERSION" | sort -V | head -n1)" != "6.3" ]]; then
    echo "Swift 6.3 or newer is required; found: $SWIFT_VERSION" >&2
    exit 1
fi

case "${1:-run}" in
    build)
        "$SWIFT_BIN" build
        ;;
    release)
        "$SWIFT_BIN" build -c release
        ;;
    run)
        "$SWIFT_BIN" run Talkies
        ;;
    clean)
        rm -rf .build
        ;;
    *)
        echo "Usage: ./run.sh [build|release|run|clean]"
        echo "  build   - Debug build"
        echo "  release - Release build"
        echo "  run     - Build and run (default)"
        echo "  clean   - Remove build directory"
        exit 1
        ;;
esac
