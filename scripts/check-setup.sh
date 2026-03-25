#!/bin/bash
# Check setup script for DictationApp
# Verifies that all dependencies are correctly installed

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# Run setup.sh in check mode
"$REPO_ROOT/setup.sh" --check
