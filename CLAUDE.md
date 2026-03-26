# DictationApp

> macOS menu bar app for voice dictation using local Whisper models.

## Quick Start

```bash
# Python setup (recommended - handles Apple Silicon PortAudio flags)
cd /Users/bensmith/whisper-dictation
./setup.sh

# Build and run (development)
cd DictationApp && swift run

# Build app bundle for distribution
cd DictationApp && ./build-app.sh && open build/

# Build beta version (separate identity for testing)
cd DictationApp && ./build-beta.sh && open build/
```

## Architecture

Swift menu bar app + Python transcription scripts. Swift calls Python via `Process` API; Python records audio, transcribes with faster-whisper, saves to Obsidian vault.

**Full docs**: [docs/index.md](docs/index.md)

## Key Files

| File | Purpose |
|------|---------|
| `DictationApp/DictationApp.swift` | App entry point (MenuBarExtra) |
| `DictationApp/TranscriptionManager.swift` | Central state coordinator |
| `DictationApp/PathManager.swift` | Dynamic path resolution for scripts |
| `DictationApp/SetupManager.swift` | First-run setup wizard logic |
| `DictationApp/SetupWizardView.swift` | Setup wizard UI |
| `DictationApp/AutoPasteManager.swift` | Accessibility-based auto-paste |
| `DictationApp/StatisticsManager.swift` | Usage tracking |
| `DictationApp/RefinementManager.swift` | AI post-processing config |
| `dictate-toggle.py` | Main script: record + transcribe |
| `warmup-model.py` | Pre-load Whisper model |
| `setup.sh` | System dependency setup and venv creation |

## Communication Flow

1. Swift calls `dictate-toggle.py` via Process API
2. Python records to `/tmp/whisper-dictation/recording.wav`
3. Python transcribes with faster-whisper
4. Python saves to Obsidian vault
5. Swift reads vault for history display

## Permissions Required

- **Microphone**: Required for audio recording (macOS will prompt on first use)
- **Accessibility**: Required for auto-paste feature (System Preferences > Privacy & Security > Accessibility)

## Configuration

- **Swift settings**: UserDefaults (model, device, vault path)
- **Python settings**: Modified directly in scripts by Swift
- **API keys**: Stored in macOS Keychain
- **Environment variables**: Passed to Python for refinement config

## Debug

```bash
# View Python script logs
tail -f /tmp/whisper-dictation/record.log

# Run Swift app with console output
cd DictationApp && swift run
```

## Documentation

- [Architecture](docs/architecture.md) - System design
- [Swift Guide](docs/swift-guide.md) - Swift patterns
- [Python Guide](docs/python-guide.md) - Script workflows
- [Features](docs/features/) - Individual feature docs
- [Troubleshooting](docs/troubleshooting.md) - Common issues

## Common Tasks

### Add Whisper Model

Add to `WhisperModel` enum in `Models.swift`:

```swift
case newModel = "new-model-name"
```

### Change Default Hotkey

Edit `GlobalHotkey.swift`:

```swift
static let toggleDictation = Self("toggleDictation",
    default: .init(.space, modifiers: .control))
```

### Change Vault Path

Use Settings UI or edit `ObsidianManager` default path.

### First-Run Setup

The app includes a setup wizard that launches automatically on first run:
- Checks system dependencies (Python, Homebrew, PortAudio, venv)
- Guides through permissions (Microphone, Accessibility optional)
- Configures Obsidian vault path (optional)
- Selects default Whisper model
- Detects already-downloaded models in HuggingFace cache

Skip the wizard or run it later from Settings.

### Opening System Settings Panes

Use URL schemes to open specific privacy panes:

```swift
// Microphone
URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")

// Accessibility
URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")

// Full Disk Access
URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")
```

### HuggingFace Cache Detection

Models are cached at `~/.cache/huggingface/hub/models--{org}--{model}/`. Check for:
1. `refs/main` file exists (contains commit SHA)
2. `snapshots/{commit-sha}/model.bin` exists

```swift
let cacheDir = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent(".cache/huggingface/hub")
    .appendingPathComponent("models--Systran--faster-whisper-base.en")
```

### Path Management

The `PathManager` handles script location across different contexts:
- **Xcode/swift build**: Finds scripts relative to build output
- **App bundle**: Looks in Resources or sibling directories
- **Development**: Uses current working directory or common locations

---

*Last updated: 2026-03-25*
