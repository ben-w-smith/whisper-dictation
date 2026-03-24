#!/usr/bin/env python3
"""
Real-time dictation with faster-whisper
Press ENTER to start recording, press ENTER again to stop and transcribe
"""

import wave
import tempfile
import pyaudio
import pyperclip
from faster_whisper import WhisperModel

# Settings
# Best for technical/developer vocabulary: distil-large-v3 (with int8 quantization for speed)
# Options: tiny.en, base.en, distil-small.en, distil-medium.en, distil-large-v3
MODEL_SIZE = "distil-large-v3"
SAMPLE_RATE = 16000
CHUNK_SIZE = 1024
CHANNELS = 1

def record_audio():
    """Record audio from microphone until user presses Enter"""
    audio = pyaudio.PyAudio()

    print("\n🎤 Recording... Press ENTER to stop")

    stream = audio.open(
        format=pyaudio.paInt16,
        channels=CHANNELS,
        rate=SAMPLE_RATE,
        input=True,
        frames_per_buffer=CHUNK_SIZE
    )

    frames = []
    input()  # Wait for Enter to stop

    print("⏹️  Stopping...")
    stream.stop_stream()
    stream.close()

    # Save to temp file
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        wf = wave.open(tmp.name, 'wb')
        wf.setnchannels(CHANNELS)
        wf.setsampwidth(audio.get_sample_size(pyaudio.paInt16))
        wf.setframerate(SAMPLE_RATE)
        wf.writeframes(b''.join(frames))
        wf.close()
        audio.terminate()
        return tmp.name

def record_audio_buffered():
    """Record audio from microphone with buffering until user presses Enter"""
    import threading
    import queue

    audio = pyaudio.PyAudio()
    q = queue.Queue()
    recording = True

    def callback(in_data, frame_count, time_info, status):
        if recording:
            q.put(in_data)
        return (None, pyaudio.paContinue)

    print("\n🎤 Recording... Press ENTER to stop")

    stream = audio.open(
        format=pyaudio.paInt16,
        channels=CHANNELS,
        rate=SAMPLE_RATE,
        input=True,
        frames_per_buffer=CHUNK_SIZE,
        stream_callback=callback
    )

    stream.start_stream()
    input()  # Wait for Enter to stop
    recording = False

    print("⏹️  Stopping...")

    stream.stop_stream()
    stream.close()

    # Collect all frames
    frames = []
    while not q.empty():
        frames.append(q.get())

    audio.terminate()

    # Save to temp file
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        wf = wave.open(tmp.name, 'wb')
        wf.setnchannels(CHANNELS)
        wf.setsampwidth(audio.get_sample_size(pyaudio.paInt16))
        wf.setframerate(SAMPLE_RATE)
        wf.writeframes(b''.join(frames))
        wf.close()
        return tmp.name

def transcribe(audio_path, model):
    """Transcribe audio file and return text"""
    print("📝 Transcribing...")
    segments, info = model.transcribe(audio_path, beam_size=5)

    text = ""
    for segment in segments:
        text += segment.text

    return text.strip()

def main():
    print("=" * 50)
    print("🎙️  Whisper Dictation")
    print("=" * 50)
    print(f"Model: {MODEL_SIZE}")
    print("Press ENTER to start recording, ENTER again to stop")
    print("Type 'q' to quit\n")

    # Load model
    print("Loading model...")
    model = WhisperModel(MODEL_SIZE, device="auto", compute_type="int8")
    print("Model loaded!\n")

    while True:
        cmd = input("Press ENTER to record (or 'q' to quit): ")
        if cmd.lower() == 'q':
            print("Goodbye!")
            break

        # Record
        audio_path = record_audio_buffered()

        # Transcribe
        text = transcribe(audio_path, model)

        if text:
            # Copy to clipboard
            pyperclip.copy(text)
            print(f"\n✅ Copied to clipboard:\n{text}\n")
        else:
            print("\n⚠️  No speech detected\n")

        # Cleanup temp file
        import os
        os.unlink(audio_path)

if __name__ == "__main__":
    main()
