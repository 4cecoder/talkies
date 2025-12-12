#!/bin/bash

# Talkies Swift macOS App Build Script
# This script builds the Swift app without requiring Xcode

set -e

echo "🎤 Building Talkies Swift macOS App..."

# Check if Swift is available
if ! command -v swift &> /dev/null; then
    echo "❌ Swift is not installed. Please install Xcode Command Line Tools."
    echo "   Run: xcode-select --install"
    exit 1
fi

# Check if we're on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "❌ This app can only be built on macOS."
    exit 1
fi

# Navigate to the Talkies directory
cd "$(dirname "$0")/Talkies"

echo "📦 Resolving dependencies..."
swift package resolve

echo "🔨 Building the app..."
swift build -c release --product Talkies

# Create the app bundle
echo "📁 Creating app bundle..."
APP_NAME="Talkies"
APP_BUNDLE="$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

# Clean up previous build
rm -rf "$APP_BUNDLE"

# Create directory structure
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy the executable
cp ".build/release/Talkies" "$MACOS_DIR/"

# Create Info.plist
cat > "$CONTENTS_DIR/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Talkies</string>
    <key>CFBundleIdentifier</key>
    <string>com.talkies.app</string>
    <key>CFBundleName</key>
    <string>Talkies</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
    <key>NSMicrophoneUsageDescription</key>
    <string>Talkies needs access to your microphone for real-time transcription.</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>CFBundleDisplayName</key>
    <string>Talkies</string>
    <key>CFBundleSpokenName</key>
    <string>Talkies</string>
</dict>
</plist>
EOF

# Create PkgInfo
echo "APPL????" > "$CONTENTS_DIR/PkgInfo"

echo "✅ Build complete! App bundle created: $APP_BUNDLE"
echo ""
echo "🚀 To run the app:"
echo "   open $APP_BUNDLE"
echo ""
echo "📝 To install the app:"
echo "   cp -R $APP_BUNDLE /Applications/"
echo ""
echo "⚠️  Note: The app requires microphone permission on first run."
echo "   The Python MLX Whisper integration must be installed separately."