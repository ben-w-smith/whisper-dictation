# Refinement

AI post-processing for transcriptions in DictationApp.

## Overview

Refinement allows AI models to improve raw Whisper transcriptions by fixing grammar, punctuation, and removing filler words. Configure your own API endpoint and model.

## Configuration

The refinement feature uses a generic OpenAI-compatible API format. Configure:

- **Base URL**: Your API endpoint (e.g., `https://api.openai.com/v1`)
- **Model**: The model name to use (e.g., `gpt-4o-mini`)
- **API Key**: Stored securely in macOS Keychain

### Popular API Endpoints

| Provider | Base URL | Example Models |
|----------|----------|----------------|
| OpenAI | `https://api.openai.com/v1` | gpt-4o-mini, gpt-5-mini, o4-mini |
| Anthropic | `https://api.anthropic.com/v1` | claude-3-5-haiku, claude-3-7-sonnet |
| DeepSeek | `https://api.deepseek.com/v1` | deepseek-chat |
| Groq | `https://api.groq.com/openai/v1` | llama-3.3-70b-versatile |
| Ollama (Local) | `http://localhost:11434/v1` | llama3.2, deepseek-r1 |

### Swift Layer

```swift
@Published var isRefinementEnabled: Bool
@Published var baseURL: String
@Published var model: String
@Published var customPrompt: String
```

### API Key Storage

API keys are stored securely in macOS Keychain:

```swift
private let keychainService = "com.whisper-dictation.refinement"
private let keychainAccount = "api-key"

func saveAPIKey(_ key: String) -> Bool { ... }
func getAPIKey() -> String? { ... }
```

### Configuration Export

Swift exports configuration to Python via environment variables:

```swift
func exportConfig() -> [String: String] {
    config["DICTATE_REFINEMENT_ENABLED"] = isRefinementEnabled ? "true" : "false"
    config["DICTATE_REFINEMENT_BASE_URL"] = baseURL
    config["DICTATE_REFINEMENT_MODEL"] = model
    config["DICTATE_REFINEMENT_API_KEY"] = apiKey
    config["DICTATE_REFINEMENT_PROMPT"] = customPrompt
    return config
}
```

## Default Prompt

```
Improve this speech-to-text transcription:
- Fix grammar and punctuation
- Remove filler words (um, uh, like, you know)
- Improve clarity while preserving meaning and tone
- Return ONLY the improved text, no explanations

Transcription:
```

## Python Integration

The Python script checks for refinement configuration:

```python
import os

if os.environ.get("DICTATE_REFINEMENT_ENABLED") == "true":
    base_url = os.environ.get("DICTATE_REFINEMENT_BASE_URL")
    model = os.environ.get("DICTATE_REFINEMENT_MODEL")
    api_key = os.environ.get("DICTATE_REFINEMENT_API_KEY")
    prompt = os.environ.get("DICTATE_REFINEMENT_PROMPT")

    text = refine_with_api(text, base_url, model, api_key, prompt)
```

## Error Handling

If refinement fails, the raw transcription is used:

```python
try:
    refined = refine_with_api(text)
except Exception as e:
    print(f"Refinement failed: {e}")
    refined = text  # Fall back to raw
```

## Development Notes

### SwiftUI Text Field Bindings

The `RefinementSettingsView` uses `@State` properties for text fields rather than direct bindings to `@Published` properties on the `RefinementManager`. This pattern is necessary because:

1. **@ObservedObject with inline initialization** (`@ObservedObject var manager = Manager.shared`) can cause binding issues with text fields - the observation lifecycle isn't properly managed by SwiftUI.

2. **@StateObject with singletons** is semantically incorrect - `@StateObject` is meant to own objects, not reference existing singletons.

3. **@MainActor on ObservableObject** combined with direct bindings can interfere with SwiftUI's binding mechanism.

**Recommended pattern:**

```swift
struct RefinementSettingsView: View {
    // Local @State properties for text fields
    @State private var baseURL = RefinementManager.shared.baseURL
    @State private var model = RefinementManager.shared.model

    var body: some View {
        TextField("URL", text: $baseURL)
            .onChange(of: baseURL) { _, newValue in
                RefinementManager.shared.baseURL = newValue
            }
    }
}
```

This ensures text input works reliably while keeping the singleton in sync.

### Key Files

| File | Purpose |
|------|---------|
| `RefinementManager.swift` | Singleton managing settings, API key in Keychain |
| `RefinementSettingsView.swift` | Settings UI with text fields, API key management |
| `dictate-toggle.py` | Receives config via environment variables |

## Cross-References

- [Transcription](transcription.md) - What gets refined
- [Python Guide](../python-guide.md) - Environment variables
- [Configuration](../api/configuration.md) - All configuration options

---

*Last updated: 2026-03-24*
