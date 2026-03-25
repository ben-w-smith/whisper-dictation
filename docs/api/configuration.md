# Configuration

Environment variables and settings for DictationApp.

## Swift Settings (UserDefaults)

### General Settings

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `selectedModel` | String | `tiny.en` | Whisper model to use |
| `selectedInputDevice` | Data | System default | Audio input device |
| `autoPasteEnabled` | Bool | `false` | Enable auto-paste |
| `autoPasteDelay` | Double | `0.3` | Delay before pasting |
| `obsidianVaultEnabled` | Bool | `false` | Enable Obsidian integration |
| `obsidianVaultPath` | String | - | Path to Obsidian vault |
| `soundsEnabled` | Bool | `true` | Enable sound effects |
| `soundVolume` | Double | `1.0` | Sound volume (0-1) |
| `soundConfiguration` | Data | Default sounds | Sound event mappings |

### Refinement Settings

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `refinementEnabled` | Bool | `false` | Enable AI refinement |
| `refinementBaseURL` | String | - | API base URL |
| `refinementModel` | String | - | Model name |
| `refinementCustomPrompt` | String | Default prompt | Custom refinement prompt |

### Statistics Settings

| Key | Type | Description |
|-----|------|-------------|
| `dictationStatistics` | Data | JSON-encoded StatisticsData |

## Environment Variables (Python)

These are passed from Swift to Python scripts:

### Refinement Configuration

| Variable | Description |
|----------|-------------|
| `DICTATE_REFINEMENT_ENABLED` | `"true"` or `"false"` |
| `DICTATE_REFINEMENT_BASE_URL` | API endpoint URL |
| `DICTATE_REFINEMENT_MODEL` | Model identifier |
| `DICTATE_REFINEMENT_API_KEY` | API key (from Keychain) |
| `DICTATE_REFINEMENT_PROMPT` | Custom prompt text |

## Python Script Constants

These are modified directly in `dictate-toggle.py`:

```python
# Model configuration
MODEL_SIZE = "tiny.en"

# Audio configuration
INPUT_DEVICE_INDEX = None  # None for system default

# Storage configuration
OBSIDIAN_VAULT = Path("/Users/bensmith/ObsidianVault/Default")
```

## Keychain Storage

API keys are stored securely in macOS Keychain:

- **Service**: `com.whisper-dictation.refinement`
- **Account**: `api-key`

## Configuration Export

Swift exports refinement config to Python:

```swift
func exportConfig() -> [String: String] {
    var config: [String: String] = [:]
    config["DICTATE_REFINEMENT_ENABLED"] = isRefinementEnabled ? "true" : "false"
    config["DICTATE_REFINEMENT_BASE_URL"] = baseURL
    config["DICTATE_REFINEMENT_MODEL"] = model
    config["DICTATE_REFINEMENT_IS_OPENAI_COMPATIBLE"] = "true"
    if let key = apiKey {
        config["DICTATE_REFINEMENT_API_KEY"] = key
    }
    config["DICTATE_REFINEMENT_PROMPT"] = customPrompt
    return config
}
```

## Default Values

### Sound Configuration

```swift
SoundConfiguration(
    startRecording: .glass,
    stopRecording: .pop,
    transcriptionReady: .hero
)
```

### Refinement Prompt

```
Improve this speech-to-text transcription:
- Fix grammar and punctuation
- Remove filler words (um, uh, like, you know)
- Improve clarity while preserving meaning and tone
- Return ONLY the improved text, no explanations

Transcription:
```

## Cross-References

- [Swift Guide](../swift-guide.md) - Settings implementation
- [Python Guide](../python-guide.md) - Environment variable usage
- [Refinement](../features/refinement.md) - AI refinement configuration

---

*Last updated: 2026-03-24*
