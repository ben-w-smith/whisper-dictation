#!/bin/bash
# Setup script for DictationApp
# Handles macOS-specific dependencies and virtual environment setup

set -e

# Color output helpers
if [[ -t 1 ]] && [[ $(tput colors 2>/dev/null || echo 0) -ge 8 ]]; then
    # Terminal supports colors
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    BOLD='\033[1m'
    NC='\033[0m' # No Color
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    BOLD=''
    NC=''
fi

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
VENV_DIR="$SCRIPT_DIR/venv"
REQUIREMENTS_FILE="$SCRIPT_DIR/requirements.txt"

# Mode flags
CHECK_MODE=false
FORCE_MODE=false
VERBOSE=false

# Print functions
print_header() {
    echo ""
    echo -e "${BLUE}==========================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}==========================================${NC}"
    echo ""
}

print_step() {
    echo -e "${BLUE}[$1]${NC} $2"
}

print_success() {
    echo -e "${GREEN}  ✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}  ⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}  ✗ ERROR: $1${NC}"
}

print_info() {
    echo -e "  $1"
}

print_suggestion() {
    echo -e "${YELLOW}  💡 Suggestion: $1${NC}"
}

# Help message
show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Setup script for DictationApp - Installs Python dependencies and configures environment.

OPTIONS:
    -h, --help      Show this help message
    -c, --check     Check current setup status without installing
    -f, --force     Reinstall from scratch (deletes venv first)
    -v, --verbose   Show verbose output during installation

EXAMPLES:
    $0                  # Standard installation
    $0 --check          # Verify setup without installing
    $0 --force          # Reinstall everything from scratch

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -c|--check)
            CHECK_MODE=true
            shift
            ;;
        -f|--force)
            FORCE_MODE=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Check mode function
check_setup() {
    print_header "DictationApp Setup Check"

    local all_good=true
    local step_num=1

    # Check Python version
    print_step "$step_num" "Checking Python version..."
    if command -v python3 &> /dev/null; then
        PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}')
        PYTHON_MAJOR=$(echo "$PYTHON_VERSION" | cut -d. -f1)
        PYTHON_MINOR=$(echo "$PYTHON_VERSION" | cut -d. -f2)

        if [ "$PYTHON_MAJOR" -lt 3 ] || ([ "$PYTHON_MAJOR" -eq 3 ] && [ "$PYTHON_MINOR" -lt 10 ]); then
            print_error "Python 3.10+ is required. Found Python $PYTHON_VERSION"
            print_suggestion "Install with: brew install python@3.12"
            all_good=false
        else
            print_success "Python $PYTHON_VERSION"
        fi
    else
        print_error "Python 3 not found"
        print_suggestion "Install with: brew install python@3.12"
        all_good=false
    fi
    ((step_num++))

    # Check for Xcode Command Line Tools
    print_step "$step_num" "Checking for Xcode Command Line Tools..."
    if xcode-select -p &> /dev/null; then
        print_success "Xcode Command Line Tools installed"
    else
        print_error "Xcode Command Line Tools not found"
        print_suggestion "Install with: xcode-select --install"
        all_good=false
    fi
    ((step_num++))

    # Check for git
    print_step "$step_num" "Checking for git..."
    if command -v git &> /dev/null; then
        GIT_VERSION=$(git --version 2>&1 | awk '{print $3}')
        print_success "git $GIT_VERSION"
    else
        print_error "git not found"
        print_suggestion "Install with: brew install git"
        all_good=false
    fi
    ((step_num++))

    # Check for Homebrew
    print_step "$step_num" "Checking for Homebrew..."
    if command -v brew &> /dev/null; then
        print_success "Homebrew installed"
    else
        print_error "Homebrew not found"
        print_suggestion "Install from: https://brew.sh"
        all_good=false
    fi
    ((step_num++))

    # Check for PortAudio
    print_step "$step_num" "Checking for PortAudio..."
    if brew list portaudio &> /dev/null 2>&1; then
        print_success "PortAudio installed"
    else
        print_warning "PortAudio not installed"
        print_suggestion "Install with: brew install portaudio"
        all_good=false
    fi
    ((step_num++))

    # Check virtual environment
    print_step "$step_num" "Checking Python virtual environment..."
    if [ -d "$VENV_DIR" ]; then
        print_success "Virtual environment exists at $VENV_DIR"

        # Check if venv is activated properly
        if [ -f "$VENV_DIR/bin/python3" ]; then
            print_success "Virtual environment is valid"

            # Try importing packages
            print_step "$step_num" "Verifying Python packages..."
            source "$VENV_DIR/bin/activate"

            # Check faster-whisper
            if python3 -c "import faster_whisper" 2>/dev/null; then
                FASTER_VERSION=$(python3 -c "import faster_whisper; print(faster_whisper.__version__)" 2>/dev/null || echo "unknown")
                print_success "faster-whisper $FASTER_VERSION"
            else
                print_warning "faster-whisper not installed or import failed"
                all_good=false
            fi

            # Check pyaudio
            if python3 -c "import pyaudio" 2>/dev/null; then
                print_success "pyaudio installed"
            else
                print_warning "pyaudio not installed or import failed"
                all_good=false
            fi

            # Check pyperclip
            if python3 -c "import pyperclip" 2>/dev/null; then
                print_success "pyperclip installed"
            else
                print_warning "pyperclip not installed or import failed"
                all_good=false
            fi

            deactivate
        else
            print_error "Virtual environment appears corrupted"
            print_suggestion "Run with --force to recreate: $0 --force"
            all_good=false
        fi
    else
        print_warning "Virtual environment not found"
        print_suggestion "Run setup script: $0"
        all_good=false
    fi

    # Summary
    print_header "Setup Check Summary"
    if $all_good; then
        print_success "All checks passed! Your environment is ready."
        echo ""
        print_info "You can now build and run the app:"
        print_info "  cd DictationApp && swift run"
        return 0
    else
        print_error "Some checks failed. Please fix the issues above."
        echo ""
        print_info "Run this script without --check to fix issues:"
        print_info "  $0"
        return 1
    fi
}

# Run check mode if requested
if $CHECK_MODE; then
    check_setup
    exit $?
fi

# Main setup
print_header "DictationApp Setup"

# Handle force mode
if $FORCE_MODE && [ -d "$VENV_DIR" ]; then
    print_warning "Force mode enabled: removing existing virtual environment..."
    rm -rf "$VENV_DIR"
    print_success "Virtual environment removed"
fi

# Step 1: Check for Xcode Command Line Tools
print_step "1/7" "Checking for Xcode Command Line Tools..."
if xcode-select -p &> /dev/null; then
    print_success "Xcode Command Line Tools installed"
else
    print_error "Xcode Command Line Tools not found"
    print_suggestion "Install with: xcode-select --install"
    echo ""
    print_info "After installing Command Line Tools, run this script again."
    exit 1
fi

# Step 2: Check for git
print_step "2/7" "Checking for git..."
if command -v git &> /dev/null; then
    GIT_VERSION=$(git --version 2>&1 | awk '{print $3}')
    print_success "git $GIT_VERSION"
else
    print_error "git not found"
    print_suggestion "Install with: brew install git"
    exit 1
fi

# Step 3: Check for Python 3.10+
print_step "3/7" "Checking Python version..."
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}')
    PYTHON_MAJOR=$(echo "$PYTHON_VERSION" | cut -d. -f1)
    PYTHON_MINOR=$(echo "$PYTHON_VERSION" | cut -d. -f2)

    if [ "$PYTHON_MAJOR" -lt 3 ] || ([ "$PYTHON_MAJOR" -eq 3 ] && [ "$PYTHON_MINOR" -lt 10 ]); then
        print_error "Python 3.10+ is required. Found Python $PYTHON_VERSION"
        print_suggestion "Install with: brew install python@3.12"
        exit 1
    fi
    print_success "Python $PYTHON_VERSION"
else
    print_error "Python 3 not found"
    print_suggestion "Install with: brew install python@3.12"
    exit 1
fi

# Step 4: Check for Homebrew
print_step "4/7" "Checking for Homebrew..."
if ! command -v brew &> /dev/null; then
    print_error "Homebrew is required to install PortAudio"
    print_suggestion "Install from: https://brew.sh"
    exit 1
fi
print_success "Homebrew found"

# Step 5: Install PortAudio
print_step "5/7" "Installing PortAudio (required for audio recording)..."
if brew list portaudio &> /dev/null 2>&1; then
    print_success "PortAudio already installed"
else
    print_info "Installing PortAudio..."
    if brew install portaudio; then
        print_success "PortAudio installed"
    else
        print_error "Failed to install PortAudio"
        print_suggestion "Try running: brew install portaudio"
        exit 1
    fi
fi

# Ensure PortAudio is linked
brew link portaudio 2>/dev/null || true

# Step 6: Create virtual environment
print_step "6/7" "Setting up Python virtual environment..."
if [ -d "$VENV_DIR" ]; then
    print_info "Virtual environment exists, updating..."
else
    print_info "Creating virtual environment..."
    if python3 -m venv "$VENV_DIR"; then
        print_success "Virtual environment created"
    else
        print_error "Failed to create virtual environment"
        print_suggestion "Check Python installation and try again"
        exit 1
    fi
fi

# Step 7: Install Python dependencies
print_step "7/7" "Installing Python dependencies..."
source "$VENV_DIR/bin/activate"

# Upgrade pip first
print_info "Upgrading pip..."
if $VERBOSE; then
    python -m pip install --upgrade pip
else
    python -m pip install --upgrade pip -q
fi

# Detect architecture for M1/M2/M3 Macs
ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
    print_info "Detected Apple Silicon (M1/M2/M3)..."
    export LDFLAGS="-L$(brew --prefix portaudio)/lib"
    export CFLAGS="-I$(brew --prefix portaudio)/include"
fi

# Install dependencies
print_info "Installing packages from requirements.txt..."
if [ ! -f "$REQUIREMENTS_FILE" ]; then
    print_error "requirements.txt not found at $REQUIREMENTS_FILE"
    exit 1
fi

if $VERBOSE; then
    pip install -r "$REQUIREMENTS_FILE"
else
    # Show progress with pip's progress bar
    pip install -r "$REQUIREMENTS_FILE"
fi

# Verify installation
print_info "Verifying installation..."
INSTALL_ERRORS=0

if ! python -c "import pyaudio" 2>/dev/null; then
    print_warning "PyAudio import check failed (may still work)"
    ((INSTALL_ERRORS++))
else
    print_success "PyAudio installed correctly"
fi

if ! python -c "import faster_whisper" 2>/dev/null; then
    print_error "faster-whisper failed to install"
    ((INSTALL_ERRORS++))
else
    FASTER_VERSION=$(python -c "import faster_whisper; print(faster_whisper.__version__)" 2>/dev/null || echo "unknown")
    print_success "faster-whisper $FASTER_VERSION installed"
fi

if ! python -c "import pyperclip" 2>/dev/null; then
    print_error "pyperclip failed to install"
    ((INSTALL_ERRORS++))
else
    print_success "pyperclip installed"
fi

deactivate

# Summary
print_header "Setup Summary"

if [ $INSTALL_ERRORS -gt 0 ]; then
    print_warning "Setup completed with $INSTALL_ERRORS error(s)"
    echo ""
    print_info "You may need to address the issues above."
    print_info "Try running with --verbose for more details: $0 --verbose"
else
    print_success "Setup completed successfully!"
fi

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

# Run check mode to show final status
print_info "Running final setup verification..."
check_setup

exit $?
