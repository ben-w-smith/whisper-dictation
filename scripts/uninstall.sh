#!/bin/bash
# Uninstall script for DictationApp
# Removes virtual environment and cached files

set -e

# Color output helpers
if [[ -t 1 ]] && [[ $(tput colors 2>/dev/null || echo 0) -ge 8 ]]; then
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
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
VENV_DIR="$REPO_ROOT/venv"
CACHE_DIR="$HOME/.cache/huggingface/hub"
WHISPER_CACHE_PATTERN="models--guillaumekln--faster-whisper"

# Print functions
print_header() {
    echo ""
    echo -e "${BLUE}==========================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}==========================================${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}  ✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}  ⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}  ✗ $1${NC}"
}

print_info() {
    echo -e "  $1"
}

# Help message
show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Uninstall script for DictationApp - Removes virtual environment and cached files.

OPTIONS:
    -h, --help          Show this help message
    -a, --all           Remove everything including Whisper model cache
    --venv-only         Remove only the virtual environment
    --cache-only        Remove only Whisper model cache

EXAMPLES:
    $0                  # Remove virtual environment only
    $0 --all            # Remove virtual environment and model cache
    $0 --cache-only     # Remove only cached models

EOF
}

# Mode flags
REMOVE_ALL=false
VENV_ONLY=false
CACHE_ONLY=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -a|--all)
            REMOVE_ALL=true
            shift
            ;;
        --venv-only)
            VENV_ONLY=true
            shift
            ;;
        --cache-only)
            CACHE_ONLY=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

print_header "DictationApp Uninstall"

# Confirm before proceeding
echo -e "${YELLOW}This will remove the following:${NC}"
if $CACHE_ONLY || $REMOVE_ALL; then
    echo "  - Whisper model cache (~several GB)"
fi
if $VENV_ONLY || $REMOVE_ALL || ! $CACHE_ONLY; then
    echo "  - Python virtual environment at: $VENV_DIR"
fi
echo ""
read -p "Continue? (y/N) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Uninstall cancelled."
    exit 0
fi

# Remove virtual environment
if ! $CACHE_ONLY; then
    if [ -d "$VENV_DIR" ]; then
        echo "Removing virtual environment..."
        rm -rf "$VENV_DIR"
        print_success "Virtual environment removed"
    else
        print_warning "Virtual environment not found at $VENV_DIR"
    fi
fi

# Remove Whisper model cache
if $REMOVE_ALL || $CACHE_ONLY; then
    echo ""
    echo "Checking for Whisper model cache..."

    if [ -d "$CACHE_DIR" ]; then
        # Find and remove Whisper model cache
        WHISPER_CACHES=$(find "$CACHE_DIR" -type d -name "*$WHISPER_CACHE_PATTERN*" 2>/dev/null)

        if [ -n "$WHISPER_CACHES" ]; then
            echo "Found Whisper model cache(s):"
            echo "$WHISPER_CACHES"
            echo ""
            read -p "Remove Whisper model cache? This cannot be undone. (y/N) " -n 1 -r
            echo ""

            if [[ $REPLY =~ ^[Yy]$ ]]; then
                while IFS= read -r cache_dir; do
                    if [ -d "$cache_dir" ]; then
                        echo "Removing: $cache_dir"
                        rm -rf "$cache_dir"
                    fi
                done <<< "$WHISPER_CACHES"
                print_success "Whisper model cache removed"
            else
                print_warning "Skipped removing model cache"
            fi
        else
            print_info "No Whisper model cache found"
        fi
    else
        print_info "No cache directory found at $CACHE_DIR"
    fi
fi

# Remove temporary files
echo ""
echo "Checking for temporary files..."
TEMP_DIR="/tmp/whisper-dictation"
if [ -d "$TEMP_DIR" ]; then
    echo "Found temporary directory: $TEMP_DIR"
    read -p "Remove temporary files? (y/N) " -n 1 -r
    echo ""

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$TEMP_DIR"
        print_success "Temporary files removed"
    else
        print_warning "Skipped removing temporary files"
    fi
else
    print_info "No temporary files found"
fi

# Summary
print_header "Uninstall Complete"

echo ""
echo "To reinstall:"
echo "  cd $REPO_ROOT && ./setup.sh"
echo ""
echo "To remove the app from your Applications folder:"
echo "  rm -rf /Applications/Dictation.app"
echo ""
