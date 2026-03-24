#!/usr/bin/env python3
"""
Warmup script - pre-loads the Whisper model into memory
Run this on app startup to avoid delay on first recording
"""

import sys
from pathlib import Path

# Add venv to path
VENV_PATH = Path(__file__).parent / "venv"
sys.path.insert(0, str(VENV_PATH / "lib" / "python3.14" / "site-packages"))

from faster_whisper import WhisperModel

# Load the model (this caches it for faster subsequent loads)
print("Loading Whisper model...")
model = WhisperModel("tiny.en", device="auto", compute_type="int8")
print("Model loaded successfully!")

# Do a quick dummy transcription to fully initialize
import tempfile
import wave
with tempfile.NamedTemporaryFile(suffix=".wav", delete=True) as tmp:
    # Create a tiny silent wav file
    wf = wave.open(tmp.name, 'wb')
    wf.setnchannels(1)
    wf.setsampwidth(2)
    wf.setframerate(16000)
    wf.writeframes(b'\x00' * 3200)  # 0.1 seconds of silence
    wf.close()

    # This initializes the model fully
    list(model.transcribe(tmp.name))

print("Model warmup complete!")
