#!/bin/bash
# Setup script for DictationApp
# Handles macOS-specific dependencies and virtual environment setup

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=========================================="
echo "  DictationApp Setup"
echo "=========================================="
echo ""

# Check for Python 3.10+
echo "[1/5] Checking Python version..."
PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}')
PYTHON_MAJOR=$(echo "$PYTHON_VERSION" | cut -d. -f1)
PYTHON_MINOR=$(echo "$PYTHON_VERSION" | cut -d. -f2)

if [ "$PYTHON_MAJOR" -lt 3 ] || ([ "$PYTHON_MAJOR" -eq 3 ] && [ "$PYTHON_MINOR" -lt 10 ]); then
    echo "ERROR: Python 3.10+ is required. Found Python $PYTHON_VERSION"
    echo "Install with: brew install python@3.12"
    exit 1
fi
echo "  Found Python $PYTHON_VERSION"

# Check for Homebrew
echo ""
echo "[2/5] Checking for Homebrew..."
if ! command -v brew &> /dev/null; then
    echo "ERROR: Homebrew is required to install PortAudio."
    echo "Install Homebrew from: https://brew.sh"
    exit 1
fi
echo "  Homebrew found"

# Install PortAudio via Homebrew (required for PyAudio)
echo ""
echo "[3/5] Installing PortAudio (required for audio recording)..."
if brew list portaudio &> /dev/null; then
    echo "  PortAudio already installed"
else
    brew install portaudio
    echo "  PortAudio installed"
fi

# Ensure PortAudio is linked
brew link portaudio 2>/dev/null || true

# Create virtual environment
echo ""
echo "[4/5] Setting up Python virtual environment..."
if [ -d "venv" ]; then
    echo "  Virtual environment exists, updating..."
else
    python3 -m venv venv
    echo "  Virtual environment created"
fi

# Install Python dependencies
echo ""
echo "[5/5] Installing Python dependencies..."
source venv/bin/activate

# Upgrade pip first
pip install --upgrade pip

# Install dependencies with PortAudio path hints for M1/M2 Macs
ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
    echo "  Detected Apple Silicon (M1/M2/M3)..."
    export LDFLAGS="-L$(brew --prefix portaudio)/lib"
    export CFLAGS="-I$(brew --prefix portaudio)/include"
fi

pip install -r requirements.txt

echo ""
echo "=========================================="
echo "  Setup Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "  1. Download a Whisper model (automatic on first run)"
echo "  2. Build the Swift app:"
echo "     cd DictationApp && ./build-app.sh"
echo "  3. Install the app:"
echo "     cp -r build/Dictation.app /Applications/"
echo ""
echo "Or run the app directly:"
echo "  cd DictationApp && swift run"
echo ""
