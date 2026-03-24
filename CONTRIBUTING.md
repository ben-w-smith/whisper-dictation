# Contributing to DictationApp

Thank you for your interest in contributing to DictationApp! This document provides guidelines and instructions for contributing.

## Development Setup

1. **Clone the repository:**
   ```bash
   git clone https://github.com/ben-w-smith/whisper-dictation.git
   cd whisper-dictation
   ```

2. **Run the setup script:**
   ```bash
   ./setup.sh
   ```

3. **Build the app:**
   ```bash
   cd DictationApp
   ./build-app.sh
   ```

## Development Workflow

### Making Changes

1. Create a feature branch:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. Make your changes and test them

3. Update the CHANGELOG.md:
   - Add your changes under the `[Unreleased]` section
   - Follow the existing format (Added, Changed, Fixed, etc.)
   - Use clear, concise descriptions

4. Commit your changes:
   ```bash
   git add -A
   git commit -m "Brief description of your changes"
   ```

5. Push and create a pull request:
   ```bash
   git push origin feature/your-feature-name
   ```

### CHANGELOG Format

The project follows [Keep a Changelog](https://keepachangelog.com/) format. When making changes, update the `[Unreleased]` section:

```markdown
## [Unreleased]

### Added
- New feature description

### Changed
- Description of changes to existing features

### Fixed
- Bug fix descriptions

### Removed
- Description of removed features
```

## Release Process

Releases are managed through semantic versioning (vMAJOR.MINOR.PATCH).

### Version Types

- **MAJOR** (v1.0.0, v2.0.0): Breaking changes
- **MINOR** (v0.1.0, v0.2.0): New features, backward compatible
- **PATCH** (v0.1.1, v0.1.2): Bug fixes, backward compatible

### Creating a Release

#### Option 1: Using the Release Script (Recommended)

```bash
# For bug fixes
./scripts/release.sh patch

# For new features
./scripts/release.sh minor

# For breaking changes
./scripts/release.sh major
```

The script will:
1. Check for uncommitted changes
2. Calculate the new version number
3. Update CHANGELOG.md
4. Create a git commit
5. Create a git tag
6. Optionally push to origin

#### Option 2: Manual Release

1. **Update CHANGELOG.md:**
   - Move items from `[Unreleased]` to a new version section
   - Add the release date
   - Update version links at the bottom

2. **Commit and tag:**
   ```bash
   git add CHANGELOG.md
   git commit -m "Release vX.Y.Z"
   git tag -a vX.Y.Z -m "Release vX.Y.Z"
   ```

3. **Push the tag:**
   ```bash
   git push origin vX.Y.Z
   ```

### Automated GitHub Release

When a tag is pushed to GitHub, a GitHub Actions workflow automatically:
1. Extracts release notes from CHANGELOG.md
2. Creates a GitHub Release with those notes

You can also create releases manually via the GitHub UI or `gh` CLI:
```bash
gh release create vX.Y.Z --generate-notes
```

## Code Style

### Swift

- Follow Swift naming conventions
- Use meaningful variable names
- Add comments for complex logic
- Keep functions focused and small

### Python

- Follow PEP 8 style guidelines
- Use type hints where appropriate
- Add docstrings for functions
- Keep functions focused and small

## Pull Request Guidelines

- PRs should be focused on a single change
- Update CHANGELOG.md with your changes
- Test your changes thoroughly
- Ensure the app builds successfully
- Reference any related issues

## Questions?

Feel free to open an issue for any questions or clarifications.
