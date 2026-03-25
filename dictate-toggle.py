#!/usr/bin/env python3
"""
Toggle dictation - press hotkey to start, press again to stop and transcribe
Post-processing with configurable AI API (OpenAI-compatible)
Saves transcriptions to Obsidian vault for cross-device sync
"""

import os
import sys
import wave
import signal
import tempfile
import subprocess
import json
import urllib.request
import urllib.error
from pathlib import Path
from datetime import datetime

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

import pyaudio
import pyperclip
from faster_whisper import WhisperModel

# Settings
MODEL_SIZE = "tiny.en"  # Fastest model for MVP testing
SAMPLE_RATE = 16000
CHUNK_SIZE = 1024
CHANNELS = 1

# Audio input device - set to None for system default, or specify index
# Device 3 is typically "USB microphone" on this system
INPUT_DEVICE_INDEX = 1  # USB microphone"

# Obsidian vault storage
OBSIDIAN_VAULT = Path("/Users/bensmith/ObsidianVault/Default")
TRANSCRIPTIONS_DIR = OBSIDIAN_VAULT / "transcriptions"

# State files
STATE_DIR = Path(tempfile.gettempdir()) / "whisper-dictation"
PID_FILE = STATE_DIR / "recording.pid"
AUDIO_FILE = STATE_DIR / "recording.wav"

# Refinement configuration (read from environment variables set by Swift app)
REFINEMENT_ENABLED = os.environ.get("DICTATE_REFINEMENT_ENABLED", "false").lower() == "true"
REFINEMENT_BASE_URL = os.environ.get("DICTATE_REFINEMENT_BASE_URL", "")
REFINEMENT_MODEL = os.environ.get("DICTATE_REFINEMENT_MODEL", "")
REFINEMENT_API_KEY = os.environ.get("DICTATE_REFINEMENT_API_KEY", "")
REFINEMENT_API_PATTERN = os.environ.get("DICTATE_REFINEMENT_API_PATTERN", "openai")
REFINEMENT_PROMPT = os.environ.get("DICTATE_REFINEMENT_PROMPT", """Improve this speech-to-text transcription:
- Fix grammar and punctuation
- Remove filler words (um, uh, like, you know)
- Improve clarity while preserving meaning and tone
- Return ONLY the improved text, no explanations

Transcription: """)


def get_input_device_index() -> int | None:
    """Find the best input device, preferring USB microphone"""
    audio = pyaudio.PyAudio()

    # First, try to find USB microphone by name
    for i in range(audio.get_device_count()):
        info = audio.get_device_info_by_index(i)
        if info['maxInputChannels'] > 0 and 'USB' in info['name']:
            print(f"Found USB microphone at index {i}: {info['name']}")
            audio.terminate()
            return i

    # Fall back to system default
    try:
        default = audio.get_default_input_device_info()
        print(f"Using default input device: {default['name']}")
        audio.terminate()
        return None
    except:
        audio.terminate()
        return None


def save_transcription(text: str, model: str) -> Path | None:
    """Save transcription to Obsidian vault if configured. Returns file path or None."""
    # Skip blank/empty transcriptions
    if not text or not text.strip():
        return None

    text = text.strip()

    # Check if Obsidian vault exists
    if not OBSIDIAN_VAULT.exists():
        print(f"Obsidian vault not found at {OBSIDIAN_VAULT}, skipping save")
        return None

    # Ensure transcriptions directory exists
    try:
        TRANSCRIPTIONS_DIR.mkdir(parents=True, exist_ok=True)
    except Exception as e:
        print(f"Could not create transcriptions directory: {e}")
        return None

    # Generate filename with timestamp
    timestamp = datetime.now()
    filename = f"{timestamp.strftime('%Y-%m-%d %H-%M-%S')}.md"
    filepath = TRANSCRIPTIONS_DIR / filename

    # Create markdown content with frontmatter
    content = f"""---
created: {timestamp.isoformat()}
model: {model}
---

{text}
"""

    try:
        filepath.write_text(content)
        return filepath
    except Exception as e:
        print(f"Could not save to Obsidian vault: {e}")
        return None


def refine_with_openai_compatible(text: str) -> str:
    """Use OpenAI-compatible API to refine transcription"""
    if not REFINEMENT_API_KEY:
        print("No API key configured for refinement")
        return text

    if not REFINEMENT_BASE_URL or not REFINEMENT_MODEL:
        print("Base URL or model not configured for refinement")
        return text

    try:
        # Build the full prompt
        full_prompt = f"{REFINEMENT_PROMPT}{text}"

        # Prepare request
        url = f"{REFINEMENT_BASE_URL.rstrip('/')}/chat/completions"
        headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {REFINEMENT_API_KEY}"
        }
        data = {
            "model": REFINEMENT_MODEL,
            "messages": [
                {"role": "user", "content": full_prompt}
            ],
            "max_tokens": 4096,
            "temperature": 0.3
        }

        print(f"Refinement request to: {url}")
        print(f"Model: {REFINEMENT_MODEL}")
        print(f"Input text: {text[:100]}...")

        # Make request
        req = urllib.request.Request(
            url,
            data=json.dumps(data).encode('utf-8'),
            headers=headers,
            method='POST'
        )

        with urllib.request.urlopen(req, timeout=30) as response:
            result = json.loads(response.read().decode('utf-8'))

            if 'choices' in result and len(result['choices']) > 0:
                refined_text = result['choices'][0]['message']['content'].strip()
                print(f"Refined text: {refined_text[:100]}...")
                return refined_text
            else:
                print(f"Unexpected response format: {result}")
                return text

    except urllib.error.HTTPError as e:
        print(f"HTTP error during refinement: {e.code} {e.reason}")
        error_body = e.read().decode('utf-8')
        print(f"Error body: {error_body}")
        return text
    except urllib.error.URLError as e:
        print(f"URL error during refinement: {e.reason}")
        return text
    except Exception as e:
        print(f"Error during refinement: {e}")
        import traceback
        traceback.print_exc()
        return text


def refine_with_anthropic(text: str) -> str:
    """Use Anthropic API to refine transcription"""
    if not REFINEMENT_API_KEY:
        print("No API key configured for refinement")
        return text

    if not REFINEMENT_BASE_URL or not REFINEMENT_MODEL:
        print("Base URL or model not configured for refinement")
        return text

    try:
        # Prepare request
        url = f"{REFINEMENT_BASE_URL.rstrip('/')}/messages"
        headers = {
            "Content-Type": "application/json",
            "x-api-key": REFINEMENT_API_KEY,
            "anthropic-version": "2023-06-01"
        }
        data = {
            "model": REFINEMENT_MODEL,
            "max_tokens": 4096,
            "system": REFINEMENT_PROMPT,
            "messages": [
                {"role": "user", "content": text}
            ]
        }

        print(f"Anthropic refinement request to: {url}")
        print(f"Model: {REFINEMENT_MODEL}")
        print(f"Input text: {text[:100]}...")

        # Make request
        req = urllib.request.Request(
            url,
            data=json.dumps(data).encode('utf-8'),
            headers=headers,
            method='POST'
        )

        with urllib.request.urlopen(req, timeout=30) as response:
            result = json.loads(response.read().decode('utf-8'))

            if 'content' in result and len(result['content']) > 0:
                refined_text = result['content'][0]['text'].strip()
                print(f"Refined text: {refined_text[:100]}...")
                return refined_text
            else:
                print(f"Unexpected response format: {result}")
                return text

    except urllib.error.HTTPError as e:
        print(f"HTTP error during refinement: {e.code} {e.reason}")
        error_body = e.read().decode('utf-8')
        print(f"Error body: {error_body}")
        return text
    except urllib.error.URLError as e:
        print(f"URL error during refinement: {e.reason}")
        return text
    except Exception as e:
        print(f"Error during refinement: {e}")
        import traceback
        traceback.print_exc()
        return text


def refine_with_gemini(text: str) -> str:
    """Use Gemini API to refine transcription"""
    if not REFINEMENT_API_KEY:
        print("No API key configured for refinement")
        return text

    if not REFINEMENT_BASE_URL or not REFINEMENT_MODEL:
        print("Base URL or model not configured for refinement")
        return text

    try:
        # Prepare request - model goes in URL path for Gemini
        url = f"{REFINEMENT_BASE_URL.rstrip('/')}/models/{REFINEMENT_MODEL}:generateContent"
        headers = {
            "Content-Type": "application/json",
            "x-goog-api-key": REFINEMENT_API_KEY
        }
        # Gemini combines system prompt and user text in the content
        full_text = f"{REFINEMENT_PROMPT}\n\n{text}"
        data = {
            "contents": [
                {"parts": [{"text": full_text}]}
            ],
            "generationConfig": {"maxOutputTokens": 4096}
        }

        print(f"Gemini refinement request to: {url}")
        print(f"Model: {REFINEMENT_MODEL}")
        print(f"Input text: {text[:100]}...")

        # Make request
        req = urllib.request.Request(
            url,
            data=json.dumps(data).encode('utf-8'),
            headers=headers,
            method='POST'
        )

        with urllib.request.urlopen(req, timeout=30) as response:
            result = json.loads(response.read().decode('utf-8'))

            if 'candidates' in result and len(result['candidates']) > 0:
                candidate = result['candidates'][0]
                if 'content' in candidate and 'parts' in candidate['content'] and len(candidate['content']['parts']) > 0:
                    refined_text = candidate['content']['parts'][0]['text'].strip()
                    print(f"Refined text: {refined_text[:100]}...")
                    return refined_text
                else:
                    print(f"Unexpected candidate format: {candidate}")
                    return text
            else:
                print(f"Unexpected response format: {result}")
                return text

    except urllib.error.HTTPError as e:
        print(f"HTTP error during refinement: {e.code} {e.reason}")
        error_body = e.read().decode('utf-8')
        print(f"Error body: {error_body}")
        return text
    except urllib.error.URLError as e:
        print(f"URL error during refinement: {e.reason}")
        return text
    except Exception as e:
        print(f"Error during refinement: {e}")
        import traceback
        traceback.print_exc()
        return text


def refine_transcription(text: str) -> str:
    """Refine transcription using configured AI API"""
    if not REFINEMENT_ENABLED:
        print("Refinement disabled")
        return text

    if not text or not text.strip():
        return text

    print(f"Refining with pattern: {REFINEMENT_API_PATTERN}")
    print(f"Base URL: {REFINEMENT_BASE_URL}")
    print(f"Model: {REFINEMENT_MODEL}")

    if REFINEMENT_API_PATTERN == "anthropic":
        return refine_with_anthropic(text)
    elif REFINEMENT_API_PATTERN == "gemini":
        return refine_with_gemini(text)
    else:
        return refine_with_openai_compatible(text)


def ensure_state_dir():
    STATE_DIR.mkdir(exist_ok=True)


def is_recording():
    if not PID_FILE.exists():
        return False
    try:
        pid = int(PID_FILE.read_text().strip())
        os.kill(pid, 0)  # Check if process is running
        return True
    except (ValueError, ProcessLookupError, PermissionError):
        PID_FILE.unlink(missing_ok=True)
        return False


def notify(title, message):
    """Show macOS notification"""
    subprocess.run([
        "osascript", "-e",
        f'display notification "{message}" with title "{title}"'
    ])


def start_recording():
    """Start recording audio in background"""
    ensure_state_dir()

    # Get the best input device
    device_index = get_input_device_index()

    # Create a subprocess that records audio
    record_script = f'''
import os
import sys
import wave
import signal
import pyaudio
from pathlib import Path

STATE_DIR = Path("{STATE_DIR}")
AUDIO_FILE = STATE_DIR / "recording.wav"
PID_FILE = STATE_DIR / "recording.pid"

SAMPLE_RATE = {SAMPLE_RATE}
CHUNK_SIZE = {CHUNK_SIZE}
CHANNELS = {CHANNELS}
INPUT_DEVICE_INDEX = 1  # USB microphone"

def cleanup(sig=None, frame=None):
    PID_FILE.unlink(missing_ok=True)
    sys.exit(0)

signal.signal(signal.SIGTERM, cleanup)
signal.signal(signal.SIGINT, cleanup)

audio = pyaudio.PyAudio()
frames = []

print(f"Recording with device: {{INPUT_DEVICE_INDEX}}")

def callback(in_data, frame_count, time_info, status):
    frames.append(in_data)
    return (None, pyaudio.paContinue)

try:
    stream = audio.open(
        format=pyaudio.paInt16,
        channels=CHANNELS,
        rate=SAMPLE_RATE,
        input=True,
        input_device_index=INPUT_DEVICE_INDEX,
        frames_per_buffer=CHUNK_SIZE,
        stream_callback=callback
    )

    stream.start_stream()
    print("Stream started successfully")

    # Keep running until PID file is deleted
    while PID_FILE.exists() and stream.is_active():
        import time
        time.sleep(0.1)

    stream.stop_stream()
    stream.close()
    audio.terminate()

    # Save audio
    print(f"Saving {{len(frames)}} frames...")
    with open(AUDIO_FILE, 'wb') as f:
        wf = wave.open(f, 'wb')
        wf.setnchannels(CHANNELS)
        wf.setsampwidth(audio.get_sample_size(pyaudio.paInt16))
        wf.setframerate(SAMPLE_RATE)
        wf.writeframes(b''.join(frames))
        wf.close()
    print(f"Audio saved to {{AUDIO_FILE}}")
except Exception as e:
    print(f"Recording error: {{e}}")
    import traceback
    traceback.print_exc()
'''

    # Write recording script to temp file
    record_file = STATE_DIR / "record.py"
    record_file.write_text(record_script)

    # Start recording process with output visible for debugging
    venv_python = VENV_PATH / "bin" / "python"
    log_file = open(STATE_DIR / "record.log", 'w')
    proc = subprocess.Popen(
        [str(venv_python), str(record_file)],
        stdout=log_file,
        stderr=log_file
    )

    PID_FILE.write_text(str(proc.pid))
    notify("🎤 Dictation", f"Recording started (device: {device_index})")


def stop_and_transcribe():
    """Stop recording and transcribe"""
    if not is_recording():
        return

    # Stop recording by removing PID file
    pid = int(PID_FILE.read_text().strip())
    PID_FILE.unlink()

    # Wait for audio file to be written
    import time
    for i in range(100):  # Wait up to 10 seconds
        if AUDIO_FILE.exists():
            # Check if file is still being written
            size1 = AUDIO_FILE.stat().st_size
            time.sleep(0.2)
            size2 = AUDIO_FILE.stat().st_size
            if size1 == size2 and size1 > 0:
                break
        time.sleep(0.1)

    if not AUDIO_FILE.exists():
        notify("❌ Dictation", "No audio recorded")
        # Print log for debugging
        log_file = STATE_DIR / "record.log"
        if log_file.exists():
            print("Recording log:", log_file.read_text())
        # Output empty transcription marker for Swift to parse
        print("TRANSCRIPTION_START")
        print("")
        print("TRANSCRIPTION_END")
        return

    # Check audio file size
    audio_size = AUDIO_FILE.stat().st_size
    print(f"Audio file size: {audio_size} bytes")

    if audio_size < 1000:  # Less than 1KB is suspicious
        notify("⚠️ Dictation", f"Very small audio ({audio_size} bytes). Check microphone.")
        log_file = STATE_DIR / "record.log"
        if log_file.exists():
            print("Recording log:", log_file.read_text())

    notify("📝 Dictation", "Transcribing...")

    # Load model and transcribe
    model = WhisperModel(MODEL_SIZE, device="auto", compute_type="int8")
    segments, info = model.transcribe(str(AUDIO_FILE), beam_size=5)

    print(f"Transcription info: duration={info.duration:.2f}s, language={info.language}")

    # Collect segments for debugging
    segment_texts = list(segment.text for segment in segments)
    print(f"Segments ({len(segment_texts)}): {segment_texts}")
    text = "".join(segment_texts).strip()
    print(f"Raw transcription: {text}")
    print(f"Raw transcription length: {len(text)} chars")

    if text:
        # Post-process with AI refinement if enabled
        if REFINEMENT_ENABLED:
            notify("✨ Dictation", f"Refining with {REFINEMENT_MODEL}...")
            text = refine_transcription(text)
            print(f"After refinement: {text}")

        # Save to Obsidian vault (skips if blank)
        saved_path = save_transcription(text, MODEL_SIZE)

        # Copy to clipboard
        pyperclip.copy(text)

        # Output transcription in a parseable format for Swift
        print("TRANSCRIPTION_START")
        print(text)
        print("TRANSCRIPTION_END")
        print(f"TRANSCRIPTION_MODEL:{MODEL_SIZE}")
        print(f"TRANSCRIPTION_TIMESTAMP:{datetime.now().isoformat()}")

        if saved_path:
            notify("✅ Dictation", f"Copied & saved: {text[:40]}{'...' if len(text) > 40 else ''}")
        else:
            notify("✅ Dictation", f"Copied: {text[:40]}{'...' if len(text) > 40 else ''}")
    else:
        notify("⚠️ Dictation", "No speech detected")
        # Output empty transcription marker for Swift to parse
        print("TRANSCRIPTION_START")
        print("")
        print("TRANSCRIPTION_END")
        print(f"TRANSCRIPTION_MODEL:{MODEL_SIZE}")
        print(f"TRANSCRIPTION_TIMESTAMP:{datetime.now().isoformat()}")

    # Cleanup
    AUDIO_FILE.unlink(missing_ok=True)


def main():
    ensure_state_dir()

    if is_recording():
        stop_and_transcribe()
    else:
        start_recording()


if __name__ == "__main__":
    main()
