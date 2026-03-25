#!/bin/bash
# Build script to create a beta macOS app bundle with separate identity

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

APP_NAME="Dictation Beta"
APP_DIR="$SCRIPT_DIR/build/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "Building $APP_NAME (Beta)..."

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

# Copy Beta Info.plist
cp "DictationApp/Resources/Info-Beta.plist" "$CONTENTS_DIR/Info.plist"

# Create PkgInfo
echo -n "APPL????" > "$CONTENTS_DIR/PkgInfo"

# Copy any additional resources (if they exist)
if [ -d "DictationApp/Resources" ]; then
    cp -R DictationApp/Resources/* "$RESOURCES_DIR/" 2>/dev/null || true
    # Remove the plist files from resources (they go in Contents)
    rm -f "$RESOURCES_DIR/Info.plist" "$RESOURCES_DIR/Info-Beta.plist" 2>/dev/null || true
fi

# Ad-hoc sign the app so it can request permissions
echo "Signing app..."
codesign --force --deep --sign - "$APP_DIR"

echo ""
echo "✅ Beta app bundle created at: $APP_DIR"
echo ""
echo "Bundle Identifier: com.bensmith.DictationBeta"
echo ""
echo "This beta version has a separate identity from the main app."
echo "It will have its own permissions and settings."
echo ""
