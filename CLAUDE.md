# DictationApp - AI Agent & Developer Documentation

> This document provides comprehensive documentation for AI agents and developers working on the DictationApp project.

## Project Overview

DictationApp is a macOS menu bar application for voice dictation using local Whisper models. It provides a native Swift/SwiftUI interface while leveraging Python scripts for audio recording and transcription via faster-whisper.

### Key Features

- Menu bar app with recording controls
- Global hotkey support (default: Control + Space)
- Multiple Whisper model options (tiny.en to distil-large-v3)
- Transcription history from Obsidian vault
- Optional Gemini AI post-processing
- Automatic model preloading (warmup)

---

## Architecture

```
+---------------------------+     +-----------------------------+
|     Swift MenuBar App     |     |      Python Scripts         |
|  (DictationApp.swift)     |     |  (dictate-toggle.py)        |
+---------------------------+     +-----------------------------+
| - MenuBarExtra (UI)       |     | - Audio Recording (PyAudio) |
| - TranscriptionManager    |<--->| - Transcription (faster-    |
| - GlobalHotkey            |     |   whisper)                  |
| - Settings (KeyboardShort |     | - Gemini Post-Processing    |
|   cuts)                   |     +-----------------------------+
+---------------------------+     |                             |
        |                         | State Files (/tmp/whisper-  |
        | reads                   | dictation/)                 |
        v                         +-----------------------------+
+---------------------------+                 |
|   Obsidian Vault          |<----------------+
|   /transcriptions/*.md    |     saves
+---------------------------+
```

### Communication Flow

1. **Swift App calls Python** via `Process` API
2. **Python records audio** to temp file in `/tmp/whisper-dictation/`
3. **Python transcribes** using faster-whisper
4. **Python saves** to Obsidian vault as markdown
5. **Swift reads** transcriptions from Obsidian vault for history display

---

## Directory Structure

```
/Users/bensmith/whisper-dictation/
+-- DictationApp/                    # Swift macOS App
|   +-- Package.swift                # Swift Package Manager config
|   +-- DictationApp/
|   |   +-- DictationApp.swift       # App entry point (MenuBarExtra)
|   |   +-- ContentView.swift        # Main UI (recording controls, history)
|   |   +-- TranscriptionManager.swift  # Central state coordinator
|   |   +-- Models.swift             # Data models (WhisperModel, Transcription)
|   |   +-- SettingsView.swift       # Settings window (model picker, hotkeys)
|   |   +-- GlobalHotkey.swift       # KeyboardShortcuts integration
|   |   +-- Resources/
|   |       +-- Info.plist           # App bundle configuration
+-- dictate-toggle.py                # Main Python script (record + transcribe)
+-- warmup-model.py                  # Pre-load Whisper model on startup
+-- dictate.py                       # Alternative: transcribe existing file
+-- dictate-global.py                # Alternative: global hotkey via pynput
+-- dictate-hotkey.py                # Alternative: hotkey using keyboard lib
+-- TRANSCRIPTION_SCHEMA.md          # Documentation for Obsidian file format
+-- venv/                            # Python virtual environment
+-- raycast/                         # Raycast extension (optional)
```

---

## Key Files Explained

### Swift Files

#### DictationApp.swift
- **Purpose**: App entry point
- **Pattern**: Uses `MenuBarExtra` for menu bar app
- **Key Components**:
  - Creates `TranscriptionManager` as `@StateObject`
  - Configures `HotkeyManager` when UI appears
  - Sets up Settings window

```swift
@main
struct DictationApp: App {
    @StateObject private var transcriptionManager = TranscriptionManager()

    var body: some Scene {
        MenuBarExtra("Dictation", systemImage: ...) {
            ContentView()
                .environmentObject(transcriptionManager)
        }
        .menuBarExtraStyle(.window)
    }
}
```

#### TranscriptionManager.swift
- **Purpose**: Central state coordinator
- **Responsibilities**:
  - Recording state management (`isRecording`)
  - Model selection and warmup
  - Loading transcriptions from Obsidian vault
  - Python script execution via `Process` API
  - Audio device enumeration

- **Key Methods**:
  - `toggleRecording()` - Start/stop recording
  - `runPythonScript(name:)` - Execute Python scripts
  - `loadTranscriptions()` - Read from Obsidian vault
  - `warmupModel()` - Pre-load model on startup

- **State Communication**: The Swift app modifies Python scripts directly by rewriting the `MODEL_SIZE` constant in `dictate-toggle.py` before calling it.

#### Models.swift
- **Data Models**:
  - `WhisperModel`: Enum of available models (tiny.en, base.en, distil variants)
  - `Transcription`: Represents a saved transcription
  - `AudioDevice`: Input device information
- **Obsidian Parsing**: `Transcription.fromObsidianFile(url:)` parses markdown files

#### GlobalHotkey.swift
- **Library**: KeyboardShortcuts (via Swift Package)
- **Default**: Control + Space
- **Pattern**: Singleton `HotkeyManager` configured with `TranscriptionManager`

### Python Files

#### dictate-toggle.py
- **Purpose**: Toggle recording on/off, transcribe when done
- **Workflow**:
  1. Check `/tmp/whisper-dictation/recording.pid` to determine state
  2. If not recording: Start subprocess recording audio
  3. If recording: Stop, transcribe, save to Obsidian, copy to clipboard

- **State Files** (in `/tmp/whisper-dictation/`):
  - `recording.pid` - PID of recording subprocess
  - `recording.wav` - Audio file
  - `record.py` - Generated recording script
  - `record.log` - Debug log

- **Subprocess Recording**: The script generates and executes a Python script inline to record audio. This allows the main process to exit while recording continues.

- **Gemini Integration**: Optional post-processing via `DICTATE_GEMINI_API_KEY` env var

#### warmup-model.py
- **Purpose**: Pre-load Whisper model on app startup
- **Why**: First transcription is slow (~5-10s) without warmup
- **Process**: Loads model, does dummy transcription with silent audio

---

## Data Flow: Recording to Obsidian

```
1. User presses hotkey (Ctrl+Space)
   |
   v
2. Swift: TranscriptionManager.toggleRecording()
   |
   v
3. Swift: runPythonScript("dictate-toggle.py")
   |
   v
4. Python: start_recording()
   - Creates /tmp/whisper-dictation/recording.pid
   - Spawns subprocess recording audio
   |
   v
5. User presses hotkey again
   |
   v
6. Python: stop_and_transcribe()
   - Removes PID file (signals subprocess to stop)
   - Waits for audio file
   - Transcribes with faster-whisper
   - Optionally improves with Gemini
   - Saves to Obsidian vault
   - Copies to clipboard
   |
   v
7. Swift: loadTranscriptions()
   - Reads markdown files from Obsidian vault
   - Updates UI with new transcription
```

---

## Important Patterns & Conventions

### Swift Patterns

1. **@MainActor**: `TranscriptionManager` and `HotkeyManager` are `@MainActor` isolated
2. **@StateObject vs @EnvironmentObject**: Manager is StateObject in app, passed as EnvironmentObject to views
3. **Process API**: Python scripts run via `Process` with piped stdout/stderr
4. **UserDefaults**: Model selection persisted via `UserDefaults.standard`

### Python Patterns

1. **Virtual Environment**: Scripts add venv to `sys.path` at runtime
2. **State Files**: Use `/tmp/whisper-dictation/` for process coordination
3. **Subprocess Recording**: Recording runs in separate process, controlled by PID file
4. **Error Handling**: Fall back to raw transcription if Gemini fails

### Code Modification Pattern

The Swift app modifies Python scripts to change settings:

```swift
// In TranscriptionManager.swift
let pattern = #"MODEL_SIZE = "[^"]+""#
let replacement = #"MODEL_SIZE = "\#(selectedModel.rawValue)""#
// ... regex replacement in dictate-toggle.py
```

---

## Building & Running

### Prerequisites

- macOS 14+
- Python 3.14 (or adjust paths in scripts)
- Xcode Command Line Tools

### Python Setup

```bash
cd /Users/bensmith/whisper-dictation
python3 -m venv venv
source venv/bin/activate
pip install faster-whisper pyaudio pyperclip google-generativeai
```

### Build Swift App

```bash
cd /Users/bensmith/whisper-dictation/DictationApp
swift build -c release
```

### Run as App Bundle

For proper microphone permissions, the app must run as a bundle:

```bash
# Build the app bundle (if configured)
# Or run directly:
.build/release/DictationApp
```

### Development Mode

```bash
swift run
```

---

## Common Development Tasks

### Adding a New Whisper Model

1. Add case to `WhisperModel` enum in `Models.swift`:
   ```swift
   case newModel = "new-model-name"
   ```

2. Add display name in `displayName` computed property

3. Add speed estimate in `speed` property

4. Model will automatically appear in UI picker

### Changing the Default Hotkey

In `GlobalHotkey.swift`:
```swift
extension KeyboardShortcuts.Name {
    static let toggleDictation = Self("toggleDictation", default: .init(.space, modifiers: .control))
}
```

### Changing Obsidian Vault Path

In `TranscriptionManager.swift`:
```swift
private let obsidianVaultPath = "/Users/bensmith/ObsidianVault/Default/transcriptions"
```

In `dictate-toggle.py`:
```python
OBSIDIAN_VAULT = Path("/Users/bensmith/ObsidianVault/Default")
```

### Enabling Gemini Post-Processing

1. Set environment variable:
   ```bash
   export DICTATE_GEMINI_API_KEY="your-api-key"
   ```

2. In `dictate-toggle.py`, set:
   ```python
   USE_GEMINI = True
   ```

---

## Common Issues & Solutions

### "No audio recorded" Error

**Cause**: Microphone permissions not granted

**Solution**:
1. Run as app bundle, not command line
2. Check System Preferences > Privacy & Security > Microphone
3. Ensure app is signed (or allow in Security settings)

### Recording Starts But No Transcription

**Cause**: Audio device not found or wrong device

**Debug**: Check `/tmp/whisper-dictation/record.log`

**Solution**: Verify `INPUT_DEVICE_INDEX` in `dictate-toggle.py` or let auto-detection work

### First Transcription is Slow

**Cause**: Model not loaded in memory

**Solution**: App runs `warmup-model.py` on startup. If skipped, first transcription takes 5-10s.

### Hotkey Not Working

**Cause**: Recorder not focused in settings

**Solution**: Open Settings > Shortcuts, click the recorder box

### Python Import Errors

**Cause**: Virtual environment not in path

**Solution**: Scripts add venv to path. Verify Python version matches (3.14 in paths).

### Blank Transcriptions Saved

**Cause**: Audio file too small or no speech detected

**Solution**: Check microphone levels, speak louder, or use better model

---

## Future Enhancement Ideas

1. **Real-time Transcription**: Stream audio and transcribe in real-time
2. **Custom Vocabulary**: Add domain-specific words for better accuracy
3. **Multi-language Support**: Support non-English models
4. **Audio Device Selection UI**: Choose microphone from settings
5. **Transcription Search**: Search through history
6. **Export Options**: Export transcriptions to other formats
7. **Keyboard Shortcut Profiles**: Different shortcuts for different contexts
8. **Auto-punctuation Toggle**: Option to disable AI punctuation
9. **Transcription Queue**: Handle multiple recordings in sequence
10. **Cloud Sync**: Sync settings across devices (not just transcriptions)

---

## Dependencies

### Swift (SPM)

- **KeyboardShortcuts** (2.0.0): Global hotkey support
  - GitHub: https://github.com/sindresorhus/KeyboardShortcuts

### Python (pip)

- **faster-whisper**: Optimized Whisper implementation
- **pyaudio**: Audio recording
- **pyperclip**: Clipboard access
- **google-generativeai**: Gemini AI integration (optional)

---

## Related Files

- [TRANSCRIPTION_SCHEMA.md](TRANSCRIPTION_SCHEMA.md) - Obsidian file format documentation
- [CHANGELOG.md](CHANGELOG.md) - Version history

---

*Last updated: 2026-03-23*
