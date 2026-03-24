# Architecture

System design and component overview for DictationApp.

## High-Level Architecture

```
+---------------------------+     +-----------------------------+
|     Swift MenuBar App     |     |      Python Scripts         |
|  (DictationApp.swift)     |     |  (dictate-toggle.py)        |
+---------------------------+     +-----------------------------+
| - MenuBarExtra (UI)       |     | - Audio Recording (PyAudio) |
| - TranscriptionManager    |<--->| - Transcription (faster-    |
| - GlobalHotkey            |     |   whisper)                  |
| - Settings (KeyboardShort |     | - AI Refinement (OpenAI API)|
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

## Communication Flow

1. **Swift App calls Python** via `Process` API
2. **Python records audio** to temp file in `/tmp/whisper-dictation/`
3. **Python transcribes** using faster-whisper
4. **Python optionally refines** via AI API
5. **Python saves** to Obsidian vault as markdown
6. **Swift reads** transcriptions from Obsidian vault for history display

## Component Breakdown

### Swift Layer (UI & State)

The Swift layer handles all user interaction and maintains application state.

- **MenuBarExtra**: Main app interface in menu bar
- **TranscriptionManager**: Central coordinator for all operations
- **Manager Classes**: Specialized managers for different concerns (AutoPaste, Statistics, Refinement, Obsidian, Sound)
- **KeyboardShortcuts**: Global hotkey handling via SPM package

### Python Layer (Processing)

The Python layer handles heavy lifting: audio capture, ML inference, and file I/O.

- **Audio Recording**: PyAudio captures microphone input
- **Transcription**: faster-whisper runs Whisper models locally
- **AI Refinement**: Optional post-processing via OpenAI-compatible APIs
- **File Management**: Saves markdown files to Obsidian vault

### State Files (`/tmp/whisper-dictation/`)

Temporary files for process coordination:

| File | Purpose |
|------|---------|
| `recording.pid` | PID of recording subprocess |
| `recording.wav` | Captured audio file |
| `record.py` | Generated recording script |
| `record.log` | Debug log |

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
   - Optionally refines with AI
   - Saves to Obsidian vault
   - Copies to clipboard
   |
   v
7. Swift: loadTranscriptions()
   - Reads markdown files from Obsidian vault
   - Updates UI with new transcription
```

## Cross-References

- [Swift Guide](swift-guide.md) - Details on Swift patterns and classes
- [Python Guide](python-guide.md) - Python script workflows
- [Recording](features/recording.md) - Audio capture implementation
- [Transcription](features/transcription.md) - Whisper model details

---

*Last updated: 2026-03-24*
