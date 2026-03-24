# Recording

Audio recording workflow and device selection in DictationApp.

## Overview

Recording is handled by the Python layer using PyAudio, with the Swift layer managing state and UI updates.

## Recording Flow

```
1. User triggers recording (hotkey or UI button)
2. Swift: TranscriptionManager.toggleRecording()
3. Swift: Play start sound, record focused element
4. Swift: runPythonScript("dictate-toggle.py")
5. Python: Check for PID file
6. Python: No PID -> start_recording()
7. Python: Create PID file, spawn recording subprocess
8. Subprocess: Record audio until PID file removed
9. User triggers stop (hotkey or UI)
10. Python: PID exists -> stop_and_transcribe()
11. Python: Remove PID, wait for audio, transcribe
12. Swift: Load new transcription, update UI, auto-paste
```

## Audio Device Selection

### Swift Layer

`TranscriptionManager` enumerates input devices using CoreAudio:

```swift
func enumerateInputDevices() {
    // Get all audio devices
    // Filter for devices with input channels
    // Create AudioDevice structs with id, name, isDefault
}
```

Device selection is persisted:

```swift
func setSelectedInputDevice(_ device: AudioDevice) {
    selectedInputDevice = device
    saveSelectedInputDevice()
}
```

### Python Layer

The device index is passed to the recording script:

```python
INPUT_DEVICE_INDEX = None  # System default

# Or specific device:
INPUT_DEVICE_INDEX = 2  # Device index from PyAudio
```

## Audio Format

Recordings use standard WAV format:

```python
FORMAT = pyaudio.paInt16
CHANNELS = 1
RATE = 16000  # 16kHz for Whisper
CHUNK = 1024
```

## State Files

Recording state is managed via files in `/tmp/whisper-dictation/`:

| File | Purpose |
|------|---------|
| `recording.pid` | Contains PID of recording subprocess |
| `recording.wav` | Audio data being recorded |
| `record.log` | Debug output from recording |

## Subprocess Architecture

Recording runs in a subprocess to allow the main process to exit:

```python
def start_recording():
    record_script = generate_record_script()
    proc = subprocess.Popen([python_path, "-c", record_script])
    (TMP_DIR / "recording.pid").write_text(str(proc.pid))
```

The subprocess monitors the PID file:

```python
while (TMP_DIR / "recording.pid").exists():
    data = stream.read(CHUNK)
    frames.append(data)
```

## Pre-Recording Actions

Before recording starts, the Swift app:

1. **Records focused element** for auto-paste
2. **Plays start sound** for user feedback
3. **Updates UI** to show recording state

## Post-Recording Actions

After recording stops:

1. **Plays stop sound** then **transcription ready sound**
2. **Updates statistics** with new transcription
3. **Performs auto-paste** if enabled
4. **Reloads transcription history**

## Cross-References

- [Architecture](../architecture.md) - System overview
- [Transcription](transcription.md) - What happens after recording
- [Auto-Paste](auto-paste.md) - Post-recording text insertion
- [Sounds](sounds.md) - Audio feedback configuration

---

*Last updated: 2026-03-24*
