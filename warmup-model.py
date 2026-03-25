#!/usr/bin/env python3
"""
Warmup script - pre-loads the Whisper model into memory
Run this on app startup to avoid delay on first recording
"""

import sys
from pathlib import Path

# Add venv to path (auto-detect Python version)
VENV_PATH = Path(__file__).parent / "venv"
# Find the site-packages directory regardless of Python version
site_packages = None
lib_path = VENV_PATH / "lib"
if lib_path.exists():
    for p in lib_path.iterdir():
        if p.name.startswith("python"):
            candidate = p / "site-packages"
            if candidate.exists():
                site_packages = candidate
                break
if site_packages:
    sys.path.insert(0, str(site_packages))

from faster_whisper import WhisperModel

# Load the model (this caches it for faster subsequent loads)
print("Loading Whisper model...")
model = WhisperModel("base.en", device="auto", compute_type="int8")
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
