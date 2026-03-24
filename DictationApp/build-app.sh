#!/bin/bash
# Build script to create a proper macOS app bundle

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

APP_NAME="Dictation"
APP_DIR="$SCRIPT_DIR/build/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "Building $APP_NAME..."

# Build with Swift Package Manager
echo "Compiling..."
swift build -c release

# Remove old app bundle
rm -rf "$APP_DIR"

# Create app bundle structure
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy executable
cp ".build/release/DictationApp" "$MACOS_DIR/$APP_NAME"

# Copy Info.plist
cp "DictationApp/Resources/Info.plist" "$CONTENTS_DIR/"

# Create PkgInfo
echo -n "APPL????" > "$CONTENTS_DIR/PkgInfo"

# Copy any additional resources (if they exist)
if [ -d "DictationApp/Resources" ]; then
    cp -R DictationApp/Resources/* "$RESOURCES_DIR/" 2>/dev/null || true
fi

# Ad-hoc sign the app so it can request permissions
echo "Signing app..."
codesign --force --deep --sign - "$APP_DIR"

echo ""
echo "✅ App bundle created at: $APP_DIR"
echo ""
echo "To install:"
echo "  cp -r \"$APP_DIR\" /Applications/"
echo ""
echo "⚠️  IMPORTANT: When you first run the app and try to record, macOS will ask for microphone permission."
echo "   You MUST click 'OK' to allow microphone access for transcription to work."
