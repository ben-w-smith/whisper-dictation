# Python Guide

Workflows and patterns for the Python transcription scripts.

## Script Overview

| Script | Purpose |
|--------|---------|
| `dictate-toggle.py` | Main script: toggle recording and transcribe |
| `warmup-model.py` | Pre-load Whisper model on startup |
| `dictate.py` | Transcribe existing audio file |
| `dictate-global.py` | Alternative: global hotkey via pynput |
| `dictate-hotkey.py` | Alternative: hotkey using keyboard library |

## Virtual Environment

Scripts add the venv to `sys.path` at runtime:

```python
import sys
sys.path.insert(0, '/Users/bensmith/whisper-dictation/venv/lib/python3.14/site-packages')
```

## dictate-toggle.py

### Configuration Constants

```python
MODEL_SIZE = "tiny.en"
INPUT_DEVICE_INDEX = None  # None for system default
OBSIDIAN_VAULT = Path("/Users/bensmith/ObsidianVault/Default")
USE_GEMINI = False
```

### State-Based Toggle

The script uses a PID file to determine current state:

```python
def main():
    pid_file = TMP_DIR / "recording.pid"

    if pid_file.exists():
        stop_and_transcribe()
    else:
        start_recording()
```

### Subprocess Recording

Recording runs in a separate process, controlled by PID file:

```python
def start_recording():
    # Generate recording script
    record_script = generate_record_script()

    # Spawn subprocess
    proc = subprocess.Popen([python_path, "-c", record_script])

    # Write PID file
    (TMP_DIR / "recording.pid").write_text(str(proc.pid))
```

The recording subprocess monitors the PID file:

```python
while (TMP_DIR / "recording.pid").exists():
    # Continue recording
    data = stream.read(CHUNK)
    frames.append(data)
```

### Transcription Workflow

```python
def stop_and_transcribe():
    # Remove PID to signal subprocess to stop
    os.remove(TMP_DIR / "recording.pid")

    # Wait for audio file
    time.sleep(0.5)

    # Transcribe with faster-whisper
    model = WhisperModel(MODEL_SIZE)
    segments, info = model.transcribe(audio_path)

    # Optional AI refinement
    if os.environ.get("DICTATE_REFINEMENT_ENABLED") == "true":
        text = refine_with_ai(text)

    # Save to Obsidian
    save_to_obsidian(text, metadata)

    # Copy to clipboard
    pyperclip.copy(text)
```

## warmup-model.py

Pre-loads the Whisper model to avoid slow first transcription:

```python
from faster_whisper import WhisperModel

model = WhisperModel("tiny.en")

# Dummy transcription with silent audio
segments, info = model.transcribe(np.zeros(16000, dtype=np.float32))
```

## State Files

All temporary files are stored in `/tmp/whisper-dictation/`:

| File | Purpose |
|------|---------|
| `recording.pid` | PID of recording subprocess (existence = recording) |
| `recording.wav` | Captured audio file |
| `record.py` | Generated recording script |
| `record.log` | Debug log |

## Environment Variables

Configuration is passed from Swift via environment variables:

| Variable | Description |
|----------|-------------|
| `DICTATE_REFINEMENT_ENABLED` | Enable AI post-processing |
| `DICTATE_REFINEMENT_BASE_URL` | API base URL |
| `DICTATE_REFINEMENT_MODEL` | Model name |
| `DICTATE_REFINEMENT_API_KEY` | API key |
| `DICTATE_REFINEMENT_PROMPT` | Custom refinement prompt |

## Error Handling

Scripts fall back gracefully on errors:

```python
# Fall back to raw transcription if refinement fails
try:
    text = refine_transcription(text)
except Exception as e:
    print(f"Refinement failed: {e}")
    # Continue with raw transcription
```

## Dependencies

```
faster-whisper     # Optimized Whisper implementation
pyaudio            # Audio recording
pyperclip          # Clipboard access
google-generativeai  # Gemini AI (optional)
openai             # OpenAI-compatible APIs (optional)
```

## Cross-References

- [Architecture](architecture.md) - System overview
- [Recording](features/recording.md) - Audio capture details
- [Transcription](features/transcription.md) - Whisper model details
- [Refinement](features/refinement.md) - AI post-processing

---

*Last updated: 2026-03-24*
