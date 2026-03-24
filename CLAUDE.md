# DictationApp

> macOS menu bar app for voice dictation using local Whisper models.

## Quick Start

```bash
# Python setup
cd /Users/bensmith/whisper-dictation
python3 -m venv venv && source venv/bin/activate
pip install faster-whisper pyaudio pyperclip google-generativeai openai

# Build and run Swift app
cd DictationApp && swift build -c release && .build/release/DictationApp
```

## Architecture

Swift menu bar app + Python transcription scripts. Swift calls Python via `Process` API; Python records audio, transcribes with faster-whisper, saves to Obsidian vault.

**Full docs**: [docs/index.md](docs/index.md)

## Key Files

| File | Purpose |
|------|---------|
| `DictationApp/DictationApp.swift` | App entry point (MenuBarExtra) |
| `DictationApp/TranscriptionManager.swift` | Central state coordinator |
| `DictationApp/AutoPasteManager.swift` | Accessibility-based auto-paste |
| `DictationApp/StatisticsManager.swift` | Usage tracking |
| `DictationApp/RefinementManager.swift` | AI post-processing config |
| `dictate-toggle.py` | Main script: record + transcribe |
| `warmup-model.py` | Pre-load Whisper model |

## Communication Flow

1. Swift calls `dictate-toggle.py` via Process API
2. Python records to `/tmp/whisper-dictation/recording.wav`
3. Python transcribes with faster-whisper
4. Python saves to Obsidian vault
5. Swift reads vault for history display

## Configuration

- **Swift settings**: UserDefaults (model, device, vault path)
- **Python settings**: Modified directly in scripts by Swift
- **API keys**: Stored in macOS Keychain
- **Environment variables**: Passed to Python for refinement config

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

---

*Last updated: 2026-03-24*
