# Transcription

Whisper model integration and configuration in DictationApp.

## Overview

Transcription uses faster-whisper, an optimized implementation of OpenAI's Whisper model that runs locally on your Mac.

## Available Models

| Model | Speed | Accuracy | Use Case |
|-------|-------|----------|----------|
| `tiny.en` | Fastest | Good | Quick dictation |
| `base.en` | Fast | Better | General use |
| `small.en` | Moderate | Great | Higher accuracy needs |
| `distil-large-v3` | Moderate | Best | Maximum accuracy |

## Model Selection

### Swift Configuration

```swift
enum WhisperModel: String, CaseIterable {
    case tinyEn = "tiny.en"
    case baseEn = "base.en"
    case smallEn = "small.en"
    case distilLargeV3 = "distil-large-v3"
}
```

### Python Configuration

The model is configured in `dictate-toggle.py`:

```python
MODEL_SIZE = "tiny.en"
```

Swift modifies this value directly before calling the script:

```swift
let pattern = #"MODEL_SIZE = "[^"]+""#
let replacement = #"MODEL_SIZE = "\#(selectedModel.rawValue)""#
```

## Model Warmup

First transcription is slow (~5-10 seconds) because the model must be loaded into memory. `warmup-model.py` pre-loads the model on app startup:

```python
from faster_whisper import WhisperModel

model = WhisperModel("tiny.en")
# Dummy transcription to load model
segments, info = model.transcribe(np.zeros(16000, dtype=np.float32))
```

## Transcription Process

```python
def transcribe_audio(audio_path: str) -> str:
    model = WhisperModel(MODEL_SIZE)

    segments, info = model.transcribe(
        audio_path,
        language="en",
        beam_size=5
    )

    text = "".join(segment.text for segment in segments)
    return text.strip()
```

## WPM Metadata

Each transcription captures timing metadata for accurate WPM (Words Per Minute) tracking:

```python
# From faster-whisper
audio_duration = info.duration  # Actual audio length in seconds

# Calculate metrics
word_count = len([w for w in text.split() if w])
wpm = (word_count / (audio_duration / 60.0)) if audio_duration > 0 else 0
```

This data is saved to Obsidian frontmatter and passed to Swift for statistics tracking.

## Model Storage

Models are downloaded and cached locally by faster-whisper:

- **Location**: `~/.cache/huggingface/hub/`
- **Size**: Varies by model (39MB for tiny.en to 3GB for large)

## Performance Tips

1. **Use English models** (`.en` suffix) for English-only dictation - they're smaller and faster
2. **Warm up on startup** - the app does this automatically
3. **Use distil-large-v3** for best accuracy/speed tradeoff on Apple Silicon

## Audio Requirements

- **Sample Rate**: 16kHz (resampled automatically)
- **Format**: Mono audio (stereo converted to mono)
- **Duration**: No hard limit, but longer audio takes longer to transcribe

## Cross-References

- [Recording](recording.md) - Audio capture before transcription
- [Refinement](refinement.md) - Post-transcription AI processing
- [Python Guide](../python-guide.md) - Python script details

---

*Last updated: 2026-03-24*
