#!/usr/bin/env python3
"""
Global hotkey listener for dictation
Press Right Control to toggle recording on/off
Requires: System Settings > Privacy & Security > Accessibility > Terminal (or whatever app runs this)
"""

import subprocess
import sys
from pathlib import Path
from pynput import keyboard

# Configuration - Right Control key
HOTKEY = keyboard.Key.ctrl_r  # Right Control key
# Alternatives: keyboard.Key.alt_r (Right Option), keyboard.Key.cmd_r (Right Command)

SCRIPT_PATH = Path(__file__).parent / "dictate-toggle.py"
VENV_PYTHON = Path(__file__).parent / "venv" / "bin" / "python"

def notify(title: str, message: str):
    """Show macOS notification"""
    subprocess.run([
        "osascript", "-e",
        f'display notification "{message}" with title "{title}"'
    ])

def toggle_dictation():
    """Call the toggle script"""
    print("🎯 Toggle triggered!")
    notify("🎤 Dictation", "Toggling...")
    result = subprocess.run([str(VENV_PYTHON), str(SCRIPT_PATH)], capture_output=True, text=True)
    if result.returncode != 0:
        print(f"Error: {result.stderr}")

def main():
    print("=" * 50)
    print("🎙️  Global Dictation Hotkey Listener")
    print("=" * 50)
    print(f"Hotkey: Right Control (press to toggle dictation)")
    print("Press ESC to quit")
    print()
    print("⚠️  REQUIRED: Grant Accessibility permissions:")
    print("   System Settings > Privacy & Security > Accessibility")
    print("   Add your Terminal app (Terminal.app or iTerm.app)")
    print("=" * 50)
    print()

    def on_press(key):
        # Debug: print any key pressed
        try:
            print(f"Key detected: {key}")
        except:
            pass

        if key == HOTKEY:
            print("✅ Right Control pressed!")
            toggle_dictation()
        elif key == keyboard.Key.esc:
            print("\nGoodbye!")
            return False  # Stop listener

    print("🎧 Listening for hotkey...")
    notify("🎤 Dictation", "Ready! Press Right Control to toggle")

    # Start keyboard listener
    with keyboard.Listener(on_press=on_press) as listener:
        listener.join()

if __name__ == "__main__":
    main()
