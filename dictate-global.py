#!/usr/bin/env python3
"""
Global hotkey dictation with faster-whisper
Press hotkey to start/stop recording, transcription auto-copies to clipboard

Setup:
1. Grant Accessibility permissions to Terminal (or the app running this script)
   System Settings > Privacy & Security > Accessibility
2. Run this script in background or as a service
"""

import os
import sys
import wave
import tempfile
import threading
import queue
import pyaudio
import pyperclip
from pynput import keyboard
from faster_whisper import WhisperModel

# Settings
# Best for technical/developer vocabulary: distil-large-v3 (with int8 quantization for speed)
MODEL_SIZE = "distil-large-v3"
HOTKEY = keyboard.KeyCode.from_char('`')  # Backtick key (change to your preference)
# Alternative hotkeys:
# HOTKEY = keyboard.Key.f13  # F13 key
# HOTKEY = keyboard.Key.cmd_r  # Right command
SAMPLE_RATE = 16000
CHUNK_SIZE = 1024
CHANNELS = 1

class DictationController:
    def __init__(self):
        self.model = None
        self.is_recording = False
        self.audio_frames = queue.Queue()
        self.recording = False
        self.audio = None
        self.stream = None

    def load_model(self):
        """Load the Whisper model"""
        print("Loading model (this may take a moment on first run)...")
        self.model = WhisperModel(MODEL_SIZE, device="auto", compute_type="int8")
        print(f"Model loaded: {MODEL_SIZE}")

    def start_recording(self):
        """Start recording from microphone"""
        self.audio = pyaudio.PyAudio()
        self.recording = True
        self.audio_frames = queue.Queue()

        def callback(in_data, frame_count, time_info, status):
            if self.recording:
                self.audio_frames.put(in_data)
            return (None, pyaudio.paContinue)

        self.stream = self.audio.open(
            format=pyaudio.paInt16,
            channels=CHANNELS,
            rate=SAMPLE_RATE,
            input=True,
            frames_per_buffer=CHUNK_SIZE,
            stream_callback=callback
        )
        self.stream.start_stream()
        print("🎤 Recording... (press hotkey to stop)")
        self.is_recording = True

    def stop_recording(self):
        """Stop recording and transcribe"""
        self.recording = False
        print("⏹️  Stopping...")

        if self.stream:
            self.stream.stop_stream()
            self.stream.close()

        # Collect frames
        frames = []
        while not self.audio_frames.empty():
            frames.append(self.audio_frames.get())

        if self.audio:
            self.audio.terminate()

        self.is_recording = False

        # Save to temp file
        if frames:
            with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
                wf = wave.open(tmp.name, 'wb')
                wf.setnchannels(CHANNELS)
                wf.setsampwidth(pyaudio.PyAudio().get_sample_size(pyaudio.paInt16))
                wf.setframerate(SAMPLE_RATE)
                wf.writeframes(b''.join(frames))
                wf.close()

                # Transcribe in background
                threading.Thread(target=self.transcribe_and_copy, args=(tmp.name,)).start()

    def transcribe_and_copy(self, audio_path):
        """Transcribe audio and copy to clipboard"""
        print("📝 Transcribing...")
        try:
            segments, info = self.model.transcribe(audio_path, beam_size=5)

            text = ""
            for segment in segments:
                text += segment.text

            text = text.strip()

            if text:
                pyperclip.copy(text)
                print(f"✅ Copied to clipboard:\n{text}\n")
                # Notify via system notification
                self.notify("Dictation Complete", text[:50] + "..." if len(text) > 50 else text)
            else:
                print("⚠️  No speech detected")
                self.notify("Dictation", "No speech detected")
        except Exception as e:
            print(f"❌ Error: {e}")
        finally:
            # Cleanup
            os.unlink(audio_path)

    def notify(self, title, message):
        """Send macOS notification"""
        os.system(f'''osascript -e 'display notification "{message}" with title "{title}"' ''')

    def toggle_recording(self):
        """Toggle recording on/off"""
        if self.is_recording:
            self.stop_recording()
        else:
            self.start_recording()

def main():
    print("=" * 50)
    print("🎙️  Global Dictation (faster-whisper)")
    print("=" * 50)
    print(f"Model: {MODEL_SIZE}")
    print(f"Hotkey: Press ` (backtick) to start/stop recording")
    print("Press ESC to quit")
    print("=" * 50)
    print()

    # Check for accessibility permissions
    print("⚠️  Make sure Terminal has Accessibility permissions:")
    print("   System Settings > Privacy & Security > Accessibility")
    print()

    controller = DictationController()

    # Load model
    controller.load_model()
    print()

    # Set up hotkey listener
    def on_press(key):
        if key == HOTKEY:
            controller.toggle_recording()
        elif key == keyboard.Key.esc:
            print("\nGoodbye!")
            return False  # Stop listener

    print("🎧 Listening for hotkey...")

    # Start keyboard listener
    with keyboard.Listener(on_press=on_press) as listener:
        listener.join()

if __name__ == "__main__":
    main()
