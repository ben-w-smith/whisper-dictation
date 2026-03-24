# DictationApp

A native macOS menu bar app for speech-to-text dictation using faster-whisper.

## Features

- Menu bar presence with recording status
- Global hotkey (default: Control+Space)
- Model selector (tiny.en, base.en, distil models)
- Transcription history stored in Obsidian vault
- Copy to clipboard with one click

## Requirements

- macOS 14.0+ (Sonoma)
- Xcode 15.0+
- Python virtual environment at `~/whisper-dictation/venv/`

## Building & Running

### Option 1: Xcode (Recommended)

1. Open Xcode
2. File → Open → Select the `Package.swift` file in this folder
3. Wait for Swift Package Manager to resolve dependencies
4. Select "DictationApp" scheme
5. Product → Run (⌘R)

### Option 2: Command Line

```bash
cd /Users/bensmith/whisper-dictation/DictationApp
swift build
swift run DictationApp
```

## Configuration

### Hotkey
- Open Settings (⌘,) → Shortcuts tab
- Click the recorder and press your desired key combination

### Model Selection
- Open Settings (⌘,) → General tab
- Choose from available models:
  - Tiny (Fastest) - ~40x realtime
  - Base - ~30x realtime
  - Distil Small - ~20x realtime
  - Distil Medium - ~7x realtime
  - Distil Large v3 (Best) - ~6x realtime

## File Structure

```
DictationApp/
├── Package.swift              # Swift Package Manager config
├── DictationApp/
│   ├── DictationApp.swift     # Main app entry point
│   ├── ContentView.swift      # Menu bar UI
│   ├── TranscriptionManager.swift  # Core logic
│   ├── GlobalHotkey.swift     # Keyboard shortcuts
│   ├── SettingsView.swift     # Settings window
│   ├── Models.swift           # Data models
│   └── Resources/
│       └── Info.plist         # App configuration
```

## Dependencies

- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) by Sindre Sorhus
  - User-customizable global keyboard shortcuts
  - No accessibility permission required
  - Mac App Store compatible
