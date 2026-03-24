#!/bin/bash
#
# Release script for DictationApp
#
# Usage:
#   ./scripts/release.sh [patch|minor|major] [release_notes]
#
# Examples:
#   ./scripts/release.sh patch
#   ./scripts/release.sh minor "Added new feature X"
#   ./scripts/release.sh major "Breaking change: redesigned API"
#
# This script:
# 1. Validates working directory is clean
# 2. Determines next version number
# 3. Updates CHANGELOG.md
# 4. Commits the changes
# 5. Creates a git tag
# 6. Pushes tag to origin (optional, prompts for confirmation)
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get the repository root
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHANGELOG="$REPO_ROOT/CHANGELOG.md"

# Change to repo root
cd "$REPO_ROOT"

# Check for uncommitted changes
if ! git diff-index --quiet HEAD --; then
    echo -e "${RED}Error: You have uncommitted changes. Please commit or stash them first.${NC}"
    git status --short
    exit 1
fi

# Get current version from the latest tag
CURRENT_VERSION=$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0")
CURRENT_VERSION=${CURRENT_VERSION#v}  # Remove 'v' prefix

echo -e "${BLUE}Current version: ${CURRENT_VERSION}${NC}"

# Determine bump type
BUMP_TYPE="${1:-patch}"
case $BUMP_TYPE in
    patch|minor|major)
        ;;
    *)
        echo -e "${RED}Error: Invalid bump type. Use 'patch', 'minor', or 'major'.${NC}"
        exit 1
        ;;
esac

# Calculate new version
IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"
case $BUMP_TYPE in
    major)
        MAJOR=$((MAJOR + 1))
        MINOR=0
        PATCH=0
        ;;
    minor)
        MINOR=$((MINOR + 1))
        PATCH=0
        ;;
    patch)
        PATCH=$((PATCH + 1))
        ;;
esac
NEW_VERSION="$MAJOR.$MINOR.$PATCH"
NEW_TAG="v$NEW_VERSION"

echo -e "${GREEN}New version: ${NEW_VERSION}${NC}"

# Get release notes from argument or prompt
RELEASE_NOTES="${2:-}"
if [ -z "$RELEASE_NOTES" ]; then
    echo -e "${YELLOW}Enter release notes (press Enter to skip):${NC}"
    read -r RELEASE_NOTES
fi

# Get today's date
TODAY=$(date +%Y-%m-%d)

# Check if there's an [Unreleased] section in CHANGELOG
if grep -q "## \[Unreleased\]" "$CHANGELOG"; then
    # Replace [Unreleased] with the new version
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS requires -i '' for in-place editing
        sed -i '' "s/## \[Unreleased\]/## \[Unreleased\]\n\n---\n\n## \[${NEW_VERSION}\] - ${TODAY}/" "$CHANGELOG"
    else
        sed -i "s/## \[Unreleased\]/## \[Unreleased\]\n\n---\n\n## \[${NEW_VERSION}\] - ${TODAY}/" "$CHANGELOG"
    fi
    echo -e "${GREEN}Updated CHANGELOG.md with version ${NEW_VERSION}${NC}"
else
    echo -e "${YELLOW}Warning: No [Unreleased] section found in CHANGELOG.md${NC}"
    echo -e "${YELLOW}Adding new version section after the header...${NC}"
    # Find the first ## after the header and insert before it
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "/^# Changelog/a\\
\\
## [${NEW_VERSION}] - ${TODAY}\\
\\
### Changed\\
- Release ${NEW_VERSION}
" "$CHANGELOG"
    else
        sed -i "/^# Changelog/a\\
\\
## [${NEW_VERSION}] - ${TODAY}\\
\\
### Changed\\
- Release ${NEW_VERSION}
" "$CHANGELOG"
    fi
fi

# Update version history summary table if it exists
if grep -q "## Version History Summary" "$CHANGELOG"; then
    # Add new row to the table
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "/## Version History Summary/,/^$/s/| Version |/| Version |\n| ${NEW_VERSION} | ${TODAY} | Release ${NEW_VERSION} |/" "$CHANGELOG" 2>/dev/null || true
    else
        sed -i "/## Version History Summary/,/^$/s/| Version |/| Version |\n| ${NEW_VERSION} | ${TODAY} | Release ${NEW_VERSION} |/" "$CHANGELOG" 2>/dev/null || true
    fi
fi

# Update the bottom links in CHANGELOG
if grep -q "\[Unreleased\]:" "$CHANGELOG"; then
    # Update the compare URLs at the bottom
    REPO_URL=$(git remote get-url origin | sed 's/\.git$//' | sed 's/git@github.com:/https:\/\/github.com\//')
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s|\[Unreleased\]: .*|\[Unreleased\]: ${REPO_URL}/compare/v${NEW_VERSION}...HEAD|" "$CHANGELOG"
        # Add link for new version if not present
        if ! grep -q "\[${NEW_VERSION}\]:" "$CHANGELOG"; then
            echo "" >> "$CHANGELOG"
            echo "[${NEW_VERSION}]: ${REPO_URL}/releases/tag/v${NEW_VERSION}" >> "$CHANGELOG"
        fi
    else
        sed -i "s|\[Unreleased\]: .*|\[Unreleased\]: ${REPO_URL}/compare/v${NEW_VERSION}...HEAD|" "$CHANGELOG"
        if ! grep -q "\[${NEW_VERSION}\]:" "$CHANGELOG"; then
            echo "" >> "$CHANGELOG"
            echo "[${NEW_VERSION}]: ${REPO_URL}/releases/tag/v${NEW_VERSION}" >> "$CHANGELOG"
        fi
    fi
fi

echo ""
echo -e "${BLUE}=== Release Summary ===${NC}"
echo -e "  Version: ${GREEN}${NEW_TAG}${NC}"
echo -e "  Date:    ${TODAY}"
echo -e "  Type:    ${BUMP_TYPE}"
echo ""

# Show git diff
echo -e "${BLUE}Changes to be committed:${NC}"
git diff "$CHANGELOG" | head -30
echo ""

# Confirm release
echo -e "${YELLOW}Create release ${NEW_TAG}? (y/n)${NC}"
read -r CONFIRM

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo -e "${RED}Release cancelled.${NC}"
    git checkout "$CHANGELOG"
    exit 0
fi

# Commit the changes
git add "$CHANGELOG"
git commit -m "Release ${NEW_TAG}"

# Create tag
git tag -a "$NEW_TAG" -m "Release ${NEW_TAG}"

echo -e "${GREEN}Created tag ${NEW_TAG}${NC}"

# Ask to push
echo ""
echo -e "${YELLOW}Push tag to origin? (y/n)${NC}"
read -r PUSH_CONFIRM

if [[ "$PUSH_CONFIRM" =~ ^[Yy]$ ]]; then
    git push origin "$NEW_TAG"
    echo -e "${GREEN}Pushed ${NEW_TAG} to origin${NC}"
    echo ""
    echo -e "${BLUE}To create a GitHub release, run:${NC}"
    echo -e "  gh release create ${NEW_TAG} --generate-notes"
    echo ""
    echo -e "${BLUE}Or visit:${NC}"
    REPO_URL=$(git remote get-url origin | sed 's/\.git$//' | sed 's/git@github.com:/https:\/\/github.com\//')
    echo -e "  ${REPO_URL}/releases/new?tag=${NEW_TAG}"
else
    echo -e "${YELLOW}Tag created locally but not pushed.${NC}"
    echo -e "Push later with: ${BLUE}git push origin ${NEW_TAG}${NC}"
fi

echo ""
echo -e "${GREEN}Release ${NEW_TAG} complete!${NC}"
