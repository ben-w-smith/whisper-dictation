#!/usr/bin/env python3
"""
Gemini remote transcription module for DictationApp.
Provides transcription via Google Gemini API as an alternative to local Whisper.
"""

import os
import sys
import time
from pathlib import Path

# Gemini model mapping
GEMINI_MODELS = {
    "gemini-lite": "gemini-3.1-flash-lite-preview",
    "gemini-flash": "gemini-3-flash-preview"
}

# Default prompt for transcription
DEFAULT_TRANSCRIPTION_PROMPT = """Transcribe this audio accurately.
- Include proper punctuation and capitalization
- Do not add any commentary or explanations
- Return only the transcribed text"""


def get_gemini_model_name(provider: str) -> str:
    """Get the Gemini model name for a provider."""
    return GEMINI_MODELS.get(provider, GEMINI_MODELS["gemini-lite"])


def transcribe_with_gemini(
    audio_path: Path,
    provider: str,
    api_key: str,
    prompt: str = DEFAULT_TRANSCRIPTION_PROMPT
) -> tuple[str, float]:
    """
    Transcribe audio using Gemini API.

    Args:
        audio_path: Path to the audio file (WAV format)
        provider: Provider identifier (gemini-lite or gemini-flash)
        api_key: Gemini API key
        prompt: Optional custom prompt for transcription

    Returns:
        Tuple of (transcribed_text, transcription_duration)

    Raises:
        SystemExit on error with appropriate error message
    """
    try:
        from google import genai
    except ImportError:
        print("ERROR: google-genai package not installed. Run: pip install google-genai", file=sys.stderr)
        sys.exit(1)

    if not api_key:
        print("ERROR: Gemini API key not configured", file=sys.stderr)
        sys.exit(1)

    if not audio_path.exists():
        print(f"ERROR: Audio file not found: {audio_path}", file=sys.stderr)
        sys.exit(1)

    model_name = get_gemini_model_name(provider)
    print(f"Transcribing with Gemini: {model_name}")
    print(f"Audio file: {audio_path} ({audio_path.stat().st_size} bytes)")

    try:
        client = genai.Client(api_key=api_key)

        # Upload audio file
        start_time = time.time()
        print("Uploading audio to Gemini...")
        audio_file = client.files.upload(file=str(audio_path))
        upload_duration = time.time() - start_time
        print(f"Upload completed in {upload_duration:.2f}s")

        # Transcribe
        print("Starting transcription...")
        transcribe_start = time.time()

        response = client.models.generate_content(
            model=model_name,
            contents=[prompt, audio_file]
        )

        transcribe_duration = time.time() - transcribe_start
        total_duration = time.time() - start_time
        print(f"Transcription completed in {transcribe_duration:.2f}s")
        print(f"Total time: {total_duration:.2f}s")

        if response.text:
            text = response.text.strip()
            print(f"Transcription length: {len(text)} characters")
            return text, transcribe_duration
        else:
            print("ERROR: Empty response from Gemini", file=sys.stderr)
            sys.exit(1)

    except Exception as e:
        error_msg = str(e)

        # Provide user-friendly error messages
        if "API_KEY" in error_msg.upper() or "UNAUTHENTICATED" in error_msg.upper() or "INVALID" in error_msg.upper():
            print(f"ERROR: Invalid Gemini API key. Please check your key at https://aistudio.google.com/apikey", file=sys.stderr)
        elif "RESOURCE_EXHAUSTED" in error_msg.upper() or "QUOTA" in error_msg.upper() or "RATE" in error_msg.upper():
            print(f"ERROR: Gemini rate limit exceeded. Free tier: 1,500 requests/day. Try again later or upgrade.", file=sys.stderr)
        elif "PERMISSION" in error_msg.upper() or "FORBIDDEN" in error_msg.upper():
            print(f"ERROR: Gemini API access denied. Ensure the Gemini API is enabled for your project.", file=sys.stderr)
        elif "TIMEOUT" in error_msg.upper() or "DEADLINE" in error_msg.upper():
            print(f"ERROR: Gemini API request timed out. Please check your network connection.", file=sys.stderr)
        elif "NETWORK" in error_msg.upper() or "CONNECTION" in error_msg.upper():
            print(f"ERROR: Network error connecting to Gemini. Please check your internet connection.", file=sys.stderr)
        else:
            print(f"ERROR: Gemini API error: {error_msg}", file=sys.stderr)

        sys.exit(1)


def transcribe_with_gemini_streaming(
    audio_path: Path,
    provider: str,
    api_key: str,
    prompt: str = DEFAULT_TRANSCRIPTION_PROMPT
) -> tuple[str, float]:
    """
    Transcribe audio using Gemini API with streaming for lower perceived latency.

    Args:
        audio_path: Path to the audio file (WAV format)
        provider: Provider identifier (gemini-lite or gemini-flash)
        api_key: Gemini API key
        prompt: Optional custom prompt for transcription

    Returns:
        Tuple of (transcribed_text, transcription_duration)

    Raises:
        SystemExit on error with appropriate error message
    """
    try:
        from google import genai
    except ImportError:
        print("ERROR: google-genai package not installed. Run: pip install google-genai", file=sys.stderr)
        sys.exit(1)

    if not api_key:
        print("ERROR: Gemini API key not configured", file=sys.stderr)
        sys.exit(1)

    if not audio_path.exists():
        print(f"ERROR: Audio file not found: {audio_path}", file=sys.stderr)
        sys.exit(1)

    model_name = get_gemini_model_name(provider)
    print(f"Transcribing with Gemini (streaming): {model_name}")

    try:
        client = genai.Client(api_key=api_key)

        # Upload audio file
        start_time = time.time()
        print("Uploading audio to Gemini...")
        audio_file = client.files.upload(file=str(audio_path))
        print("Upload completed")

        # Stream transcription
        print("Starting streaming transcription...")
        transcribe_start = time.time()

        text_parts = []
        for chunk in client.models.generate_content_stream(
            model=model_name,
            contents=[prompt, audio_file]
        ):
            if chunk.text:
                text_parts.append(chunk.text)
                # Print chunk for real-time feedback
                print(chunk.text, end='', flush=True)

        transcribe_duration = time.time() - transcribe_start
        print()  # Newline after streaming

        text = ''.join(text_parts).strip()
        print(f"Transcription completed in {transcribe_duration:.2f}s")

        if text:
            return text, transcribe_duration
        else:
            print("ERROR: Empty response from Gemini", file=sys.stderr)
            sys.exit(1)

    except Exception as e:
        error_msg = str(e)

        # Provide user-friendly error messages (same as non-streaming)
        if "API_KEY" in error_msg.upper() or "UNAUTHENTICATED" in error_msg.upper():
            print(f"ERROR: Invalid Gemini API key", file=sys.stderr)
        elif "RESOURCE_EXHAUSTED" in error_msg.upper():
            print(f"ERROR: Gemini rate limit exceeded", file=sys.stderr)
        else:
            print(f"ERROR: Gemini API error: {error_msg}", file=sys.stderr)

        sys.exit(1)


if __name__ == "__main__":
    # Test mode - requires audio file path and API key as arguments
    if len(sys.argv) < 3:
        print("Usage: python remote_gemini.py <audio_file> <api_key> [provider]")
        print("  provider: gemini-lite (default) or gemini-flash")
        sys.exit(1)

    audio_file = Path(sys.argv[1])
    key = sys.argv[2]
    prov = sys.argv[3] if len(sys.argv) > 3 else "gemini-lite"

    text, duration = transcribe_with_gemini(audio_file, prov, key)
    print(f"\n--- Transcription ---\n{text}\n--- End ---")
    print(f"Duration: {duration:.2f}s")
