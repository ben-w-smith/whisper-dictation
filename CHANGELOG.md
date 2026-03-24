# Changelog

All notable changes to the DictationApp project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

### Added
- Initial documentation suite (CLAUDE.md, CHANGELOG.md)
- TRANSCRIPTION_SCHEMA.md for Obsidian file format

---

## [0.2.0] - 2026-03-23

### Added

- **Auto-Paste**: Automatically paste transcriptions into the focused app
  - Uses macOS Accessibility API for direct text insertion
  - Falls back to Cmd+V if direct insertion fails
  - Detects app switching during recording (skips paste)
  - Skips password fields and secure input
  - Configurable delay (0-2 seconds)
  - Requires Accessibility permission

- **Transcription Statistics**: Track your dictation usage
  - Word counts (total, today, this week, this month)
  - Streak tracking (current and longest)
  - Session count and estimated WPM
  - Most productive day
  - Model usage breakdown
  - Achievements (1K/10K words, 7/30 day streaks)
  - Compact stats row in menu bar

- **Sound Effects**: Audio feedback for recording states
  - Start/stop recording sounds
  - Transcription ready notification
  - 13 system sounds to choose from
  - Configurable in Settings > Sounds

- **Mouse Button Shortcuts**: Toggle recording with mouse buttons
  - Side buttons (Button 4/5) support
  - Requires Accessibility permission
  - Configurable in Settings > Shortcuts

- **Microphone Selection**: Choose input device
  - Lists all available microphones
  - System default option
  - Persisted across sessions

- **AI Refinement Updates**: Updated all providers with March 2026 models
  - OpenAI: GPT-5-mini, O4-mini, O3
  - DeepSeek: Reasoner model
  - Moonshot: Kimi K2 models
  - Zhipu: GLM-4.6, GLM-4.5
  - Qwen: Qwen3-Max
  - Groq: Llama-4-Scout
  - Anthropic: Claude 3.7 Sonnet
  - Ollama: Llama 3.3, DeepSeek R1

### Changed
- Stats moved to Settings tab for easier navigation

---

## [0.1.0] - 2026-03-23

### Added

#### Core Features
- **Menu Bar App**: Native macOS menu bar application using SwiftUI MenuBarExtra
  - Shows recording status with dynamic icon (waveform / waveform.badge.mic)
  - Quick access to recording controls
  - Model status indicator in header

- **Voice Recording**: Toggle-based audio recording
  - Press hotkey to start recording
  - Press again to stop and transcribe
  - Automatic USB microphone detection (falls back to system default)
  - Audio saved as WAV (16kHz, mono, 16-bit)

- **Local Whisper Transcription**: Uses faster-whisper for speech-to-text
  - Runs entirely on-device (no cloud required)
  - Automatic device selection (CPU/GPU/MPS)
  - INT8 quantization for efficiency

- **Model Selection**: Choose from multiple Whisper models
  - `tiny.en` - Fastest (~40x realtime)
  - `base.en` - Balanced (~30x realtime)
  - `distil-small.en` - Good accuracy (~20x realtime)
  - `distil-medium.en` - Better accuracy (~7x realtime)
  - `distil-large-v3` - Best accuracy (~6x realtime)

- **Model Warmup**: Pre-loads model on app startup
  - Avoids 5-10 second delay on first transcription
  - Runs `warmup-model.py` automatically

- **Obsidian Integration**: Transcriptions saved to Obsidian vault
  - Markdown files with YAML frontmatter
  - Timestamp and model metadata
  - Automatic sync via Obsidian's existing sync
  - History view in app reads from vault

- **Global Hotkey Support**: System-wide keyboard shortcut
  - Default: Control + Space
  - Customizable via Settings > Shortcuts
  - Uses KeyboardShortcuts Swift package

- **Clipboard Integration**: Transcriptions automatically copied
  - Text available immediately after transcription
  - Paste into any application

- **Gemini Post-Processing** (Optional): AI-powered text improvement
  - Fixes grammar and punctuation
  - Removes filler words
  - Requires `DICTATE_GEMINI_API_KEY` environment variable
  - Currently disabled by default for debugging

#### User Interface
- **ContentView**: Main menu bar popover
  - Recording toggle button with visual feedback
  - Model selector dropdown
  - Transcription history list
  - Copy button for each transcription
  - Relative timestamps (e.g., "2 minutes ago")

- **Settings Window**: Configuration panel
  - General tab: Model selection, Launch at Login
  - Shortcuts tab: Hotkey recorder

- **Status Indicators**:
  - Recording state (red icon when active)
  - Model loading state (spinner)
  - Ready/Not loaded status

#### Technical Implementation
- **Swift/SwiftUI**: Native macOS app
  - `@MainActor` for thread safety
  - `@StateObject` / `@EnvironmentObject` patterns
  - Combine for reactive updates

- **Python Backend**: Audio and transcription
  - PyAudio for recording
  - faster-whisper for transcription
  - Subprocess pattern for background recording

- **State Management**: `/tmp/whisper-dictation/`
  - `recording.pid` - Process tracking
  - `recording.wav` - Audio buffer
  - `record.log` - Debug output

- **macOS Notifications**: Native notifications
  - Recording started
  - Transcribing...
  - Copied & saved
  - Error messages

### Technical Details

#### File Format
Transcriptions saved as markdown with YAML frontmatter:
```markdown
---
created: 2026-03-23T17:30:45.123456
model: tiny.en
---

The transcribed text...
```

#### Supported Platforms
- macOS 14.0+ (Sonoma and later)
- Apple Silicon and Intel Macs

#### Dependencies
- Swift: KeyboardShortcuts 2.0.0
- Python: faster-whisper, pyaudio, pyperclip, google-generativeai

### Known Issues
- Gemini post-processing disabled due to "You" bug
- Hotkey may require clicking recorder box in settings first
- First model load still takes time if warmup skipped

---

## Version History Summary

| Version | Date | Highlights |
|---------|------|------------|
| 0.1.0 | 2026-03-23 | Initial release with core features |

---

[Unreleased]: https://github.com/user/dictation-app/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/user/dictation-app/releases/tag/v0.1.0
