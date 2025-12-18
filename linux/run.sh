#!/usr/bin/env bash
# Talkies Linux - Development Helper Script
# Convenience wrapper for common development tasks

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored message
print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Check if zig is installed
check_zig() {
    if ! command -v zig &> /dev/null; then
        print_error "Zig compiler not found!"
        echo "Install from: https://ziglang.org/download/"
        exit 1
    fi
    print_success "Zig $(zig version) found"
}

# Check system dependencies
check_deps() {
    print_info "Checking system dependencies..."

    local missing=()

    # Check PulseAudio
    if ! pkg-config --exists libpulse-simple 2>/dev/null; then
        missing+=("libpulse-dev (or pulseaudio-libs-devel)")
    fi

    # Check clipboard tools
    if [[ -n "$WAYLAND_DISPLAY" ]] || [[ "$XDG_SESSION_TYPE" == "wayland" ]]; then
        command -v wl-copy &>/dev/null || missing+=("wl-clipboard")
    else
        command -v xclip &>/dev/null || missing+=("xclip")
    fi

    # Check xdotool
    command -v xdotool &>/dev/null || missing+=("xdotool")

    if [[ ${#missing[@]} -gt 0 ]]; then
        print_warning "Missing dependencies: ${missing[*]}"
        echo "Install with:"
        echo "  Ubuntu/Debian: sudo apt install ${missing[*]}"
        echo "  Arch Linux: sudo pacman -S ${missing[*]}"
        echo "  Fedora: sudo dnf install ${missing[*]}"
        return 1
    else
        print_success "All dependencies installed"
    fi
}

# Build the project
build() {
    local mode="${1:-debug}"
    print_info "Building in $mode mode..."

    if [[ "$mode" == "release" ]]; then
        zig build -Doptimize=ReleaseFast
    else
        zig build
    fi

    print_success "Build complete: zig-out/bin/talkies"
}

# Run tests
test() {
    print_info "Running tests..."
    zig build test
    print_success "All tests passed"
}

# Run the application
run() {
    local cmd="${1:-help}"
    shift || true

    print_info "Running: talkies $cmd $*"
    zig build run -- "$cmd" "$@"
}

# Clean build artifacts
clean() {
    print_info "Cleaning build artifacts..."
    rm -rf zig-out .zig-cache
    print_success "Clean complete"
}

# Install to user bin
install() {
    print_info "Installing to ~/.local/bin/..."

    # Build release version first
    build release

    mkdir -p ~/.local/bin
    cp zig-out/bin/talkies ~/.local/bin/
    chmod +x ~/.local/bin/talkies

    print_success "Installed to ~/.local/bin/talkies"

    # Check if ~/.local/bin is in PATH
    if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
        print_warning "~/.local/bin is not in your PATH"
        echo "Add to your ~/.bashrc or ~/.zshrc:"
        echo '  export PATH="$HOME/.local/bin:$PATH"'
    fi
}

# Download whisper models
download_models() {
    local model="${1:-base}"
    print_info "Downloading whisper model: $model"

    build
    zig-out/bin/talkies models "$model"
}

# Quick test: record 5 seconds of audio
quick_test() {
    print_info "Testing audio recording (5 seconds)..."
    build
    zig-out/bin/talkies audio
}

# Development watch mode (requires inotifywait)
dev() {
    if ! command -v inotifywait &> /dev/null; then
        print_error "inotifywait not found (install inotify-tools)"
        exit 1
    fi

    print_info "Watching for changes in src/..."
    print_info "Press Ctrl+C to stop"

    while true; do
        inotifywait -r -e modify src/ 2>/dev/null || true
        echo ""
        print_info "File changed, rebuilding..."
        if zig build 2>&1; then
            print_success "Build successful"
            if zig build test 2>&1; then
                print_success "Tests passed"
            else
                print_error "Tests failed"
            fi
        else
            print_error "Build failed"
        fi
        echo ""
    done
}

# Show help
show_help() {
    cat << EOF
${BLUE}Talkies Linux - Development Helper${NC}

Usage: ./run.sh <command> [args]

${GREEN}Build Commands:${NC}
  build [debug|release]  Build the project (default: debug)
  test                   Run all tests
  clean                  Remove build artifacts
  install                Build and install to ~/.local/bin

${GREEN}Run Commands:${NC}
  run [command]          Build and run talkies
  quick                  Record → transcribe → paste
  record                 Record audio only
  audio                  Test microphone (5s recording)
  config                 Show configuration
  models [model]         Download whisper model (default: base)

${GREEN}Development Commands:${NC}
  dev                    Watch mode (auto-rebuild on changes)
  deps                   Check system dependencies
  quick-test             Quick audio recording test

${GREEN}Examples:${NC}
  ./run.sh build         # Debug build
  ./run.sh build release # Release build
  ./run.sh test          # Run tests
  ./run.sh run help      # Run talkies help
  ./run.sh quick-test    # Test audio recording
  ./run.sh models base   # Download base model
  ./run.sh install       # Install to ~/.local/bin
  ./run.sh dev           # Watch mode for development

${GREEN}Dependencies:${NC}
  ./run.sh deps          # Check all dependencies

${BLUE}For more info, see docs/BUILD.md${NC}
EOF
}

# Main script logic
main() {
    check_zig

    case "${1:-help}" in
        build)
            build "${2:-debug}"
            ;;
        test)
            test
            ;;
        run)
            shift
            run "$@"
            ;;
        clean)
            clean
            ;;
        install)
            install
            ;;
        quick|record|audio|config|help)
            run "$@"
            ;;
        models)
            download_models "${2:-base}"
            ;;
        quick-test)
            quick_test
            ;;
        dev|watch)
            dev
            ;;
        deps|check-deps)
            check_deps
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            print_error "Unknown command: $1"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
