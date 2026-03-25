# Dictation

A native macOS menu bar app for voice dictation using local Whisper models. Fast, private, and works offline.

## Quick Start

```bash
git clone https://github.com/yourusername/whisper-dictation.git
cd whisper-dictation && ./setup.sh
cd DictationApp && ./build-app.sh && cp -r build/Dictation.app /Applications/
```

Then open the app from /Applications, grant microphone permission when prompted, and you're ready to dictate!

## Features

- **Native macOS menu bar app** - Always accessible, stays out of your way
- **Local Whisper transcription** - Your audio never leaves your Mac
- **Multiple model sizes** - From tiny.en (fastest) to large-v3 (most accurate)
- **Global hotkey support** - Default: Control + Space
- **Mouse button shortcut** - Use side mouse buttons to toggle recording
- **AI refinement** - Optional post-processing with 11+ AI providers
- **Obsidian integration** - Save transcriptions to your vault
- **Sound effects** - Audio feedback for recording states
- **Microphone selection** - Choose your preferred input device

## Requirements

- macOS 14.0 or later
- Python 3.10+ (for transcription backend)
- [Homebrew](https://brew.sh) (for PortAudio installation)
- Microphone access

## Installation

### Quick Start (Recommended)

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/whisper-dictation.git
   cd whisper-dictation
   ```

2. Run the setup script (handles all dependencies including PortAudio):
   ```bash
   ./setup.sh
   ```

3. Build and install the app:
   ```bash
   cd DictationApp
   ./build-app.sh
   cp -r build/Dictation.app /Applications/
   ```

### Manual Installation

If you prefer to install manually:

1. **Clone the repository:**
   ```bash
   git clone https://github.com/yourusername/whisper-dictation.git
   cd whisper-dictation
   ```

2. **Install PortAudio** (required for audio recording):
   ```bash
   brew install portaudio
   ```

3. **Set up Python environment:**
   ```bash
   python3 -m venv venv
   source venv/bin/activate

   # For Apple Silicon Macs (M1/M2/M3):
   export LDFLAGS="-L$(brew --prefix portaudio)/lib"
   export CFLAGS="-I$(brew --prefix portaudio)/include"

   pip install -r requirements.txt
   ```

4. **Build and install the Swift app:**
   ```bash
   cd DictationApp
   ./build-app.sh
   cp -r build/Dictation.app /Applications/
   ```

### Download Pre-built Release

Download the latest release from the [Releases](releases) page. Note: You still need to set up the Python environment as described above.

## Usage

1. **Launch the app** - Look for the waveform icon in your menu bar
2. **Start recording** - Click "Start Recording" or press your hotkey (default: Control + Space)
3. **Speak** - Talk naturally into your microphone
4. **Stop recording** - Click "Stop Recording" or press the hotkey again
5. **Done!** - Your transcription is copied to the clipboard

## Configuration

### First-Run Setup

When you first launch the app, a setup wizard will guide you through:
1. System dependency check
2. Permission requests (Microphone, optional Accessibility)
3. Obsidian vault configuration (optional)
4. Whisper model selection

You can skip the wizard and configure these later in Settings.

### Settings

Open Settings (Cmd+, or click Settings button) to configure:

- **Model Selection** - Choose Whisper model size
- **Microphone** - Select input device
- **Obsidian Vault** - Enable saving to your vault
- **Hotkeys** - Set keyboard and mouse shortcuts
- **AI Refinement** - Configure post-processing
- **Sounds** - Enable/disable audio feedback

### AI Refinement Providers

Supports 11+ AI providers for text refinement:

| Provider | Type | API Format |
|----------|------|------------|
| OpenAI | Cloud | OpenAI-compatible |
| Anthropic (Claude) | Cloud | Special API |
| Google (Gemini) | Cloud | Special API |
| DeepSeek | Cloud | OpenAI-compatible |
| Moonshot / Kimi | Cloud | OpenAI-compatible |
| Zhipu AI (GLM) | Cloud | OpenAI-compatible |
| Qwen (Alibaba) | Cloud | OpenAI-compatible |
| Groq | Cloud | OpenAI-compatible |
| Together AI | Cloud | OpenAI-compatible |
| Ollama | Local | OpenAI-compatible |
| LM Studio | Local | OpenAI-compatible |

### Keyboard Shortcuts

- **Control + Space** (default) - Toggle recording
- **Custom shortcuts** - Set in Settings > Shortcuts

### Mouse Shortcuts

- **Side buttons** (Button 4/5) - Toggle recording
- Requires Accessibility permission

## Privacy

- **Local processing** - Whisper runs entirely on your Mac
- **No cloud transcription** - Your audio never leaves your device
- **Optional AI refinement** - Only sends text if you enable it
- **API keys stored in Keychain** - Secure storage for sensitive data

## Troubleshooting

### PyAudio/PortAudio installation fails

PyAudio requires PortAudio to be installed via Homebrew:

```bash
# Install PortAudio
brew install portaudio
brew link portaudio

# If linking fails, try:
brew unlink portaudio && brew link portaudio

# For Apple Silicon Macs, set compiler flags:
export LDFLAGS="-L$(brew --prefix portaudio)/lib"
export CFLAGS="-I$(brew --prefix portaudio)/include"
pip install pyaudio
```

### "No audio recorded" error

1. Ensure microphone permission is granted
2. Check that the correct microphone is selected in Settings
3. Try recording with the built-in microphone to test

### Transcription quality issues

1. Try a larger model (base.en, small.en)
2. Check microphone input levels
3. Ensure quiet recording environment

### Hotkey not working

1. Open Settings > Shortcuts
2. Click the recorder field and press your desired key combination
3. Ensure no other app is using the same shortcut

### Mouse button shortcut not working

1. Grant Accessibility permission when prompted
2. Go to System Settings > Privacy & Security > Accessibility
3. Ensure Dictation is in the list and enabled

## Development

### Project Structure

```
whisper-dictation/
├── DictationApp/           # Swift macOS app
│   ├── DictationApp.swift  # App entry point
│   ├── ContentView.swift   # Main UI
│   ├── TranscriptionManager.swift
│   ├── SettingsView.swift
│   └── ...
├── dictate-toggle.py       # Main Python script
├── warmup-model.py         # Pre-load model on startup
├── CLAUDE.md              # AI agent documentation
└── CHANGELOG.md           # Version history
```

### Architecture

The app uses a hybrid architecture:
- **Swift/SwiftUI** - Native macOS UI, menu bar integration, settings
- **Python** - Audio recording and Whisper transcription
- **Process API** - Swift launches Python scripts as subprocesses

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [faster-whisper](https://github.com/SYSTRAN/faster-whisper) - Optimized Whisper implementation
- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) - Global hotkey support
- [OpenAI Whisper](https://github.com/openai/whisper) - Original Whisper model
