# DictationApp Documentation

> Comprehensive documentation for the DictationApp macOS voice dictation application.

## Overview

DictationApp is a macOS menu bar application for voice dictation using local Whisper models. It provides a native Swift/SwiftUI interface while leveraging Python scripts for audio recording and transcription via faster-whisper.

## Documentation Index

### Core Documentation

| Document | Description |
|----------|-------------|
| [Architecture](architecture.md) | System design, components, and communication flow |
| [Swift Guide](swift-guide.md) | Swift app patterns, conventions, and key classes |
| [Python Guide](python-guide.md) | Python script workflows and patterns |
| [Troubleshooting](troubleshooting.md) | Common issues and solutions |

### Feature Documentation

| Document | Description |
|----------|-------------|
| [Recording](features/recording.md) | Audio recording workflow and device selection |
| [Transcription](features/transcription.md) | Whisper model integration and configuration |
| [Auto-Paste](features/auto-paste.md) | Automatic text insertion via Accessibility API |
| [Statistics](features/statistics.md) | Usage tracking, streaks, and achievements |
| [Refinement](features/refinement.md) | AI post-processing for transcriptions |
| [Obsidian Integration](features/obsidian.md) | Vault connection and file management |
| [Sound Effects](features/sounds.md) | Audio feedback configuration |

### API Reference

| Document | Description |
|----------|-------------|
| [Configuration](api/configuration.md) | Environment variables and settings |

## Quick Links

- **Project Root**: `/Users/bensmith/whisper-dictation/`
- **Swift App**: `/Users/bensmith/whisper-dictation/DictationApp/`
- **Python Scripts**: `/Users/bensmith/whisper-dictation/*.py`
- **Transcriptions**: Configured Obsidian vault `/transcriptions/`

## Key Files at a Glance

### Swift Application (`DictationApp/DictationApp/`)

| File | Purpose |
|------|---------|
| `DictationApp.swift` | App entry point with MenuBarExtra |
| `TranscriptionManager.swift` | Central state coordinator |
| `ContentView.swift` | Main UI with recording controls |
| `Models.swift` | Data models (WhisperModel, Transcription) |
| `AutoPasteManager.swift` | Accessibility-based auto-paste |
| `StatisticsManager.swift` | Usage tracking and achievements |
| `RefinementManager.swift` | AI post-processing configuration |
| `ObsidianManager.swift` | Vault path configuration |
| `SoundManager.swift` | Sound effect playback |
| `GlobalHotkey.swift` | KeyboardShortcuts integration |

### Python Scripts (`/Users/bensmith/whisper-dictation/`)

| File | Purpose |
|------|---------|
| `dictate-toggle.py` | Main script: toggle recording and transcribe |
| `warmup-model.py` | Pre-load Whisper model on startup |
| `dictate.py` | Alternative: transcribe existing audio file |
| `dictate-global.py` | Alternative: global hotkey via pynput |
| `dictate-hotkey.py` | Alternative: hotkey using keyboard library |

## Related Documentation

- [TRANSCRIPTION_SCHEMA.md](../TRANSCRIPTION_SCHEMA.md) - Obsidian file format
- [CHANGELOG.md](../CHANGELOG.md) - Version history

---

*Last updated: 2026-03-24*
