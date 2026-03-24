# Refinement

AI post-processing for transcriptions in DictationApp.

## Overview

Refinement allows AI models to improve raw Whisper transcriptions by fixing grammar, punctuation, and removing filler words. Multiple AI providers are supported.

## Supported Providers

### OpenAI-Compatible APIs

| Provider | Base URL | Notes |
|----------|----------|-------|
| OpenAI | `https://api.openai.com/v1` | GPT-4o, GPT-4o-mini |
| DeepSeek | `https://api.deepseek.com/v1` | deepseek-chat |
| Moonshot | `https://api.moonshot.cn/v1` | Kimi models |
| Zhipu | `https://open.bigmodel.cn/api/paas/v4` | GLM models |
| Qwen | `https://dashscope.aliyuncs.com/compatible-mode/v1` | Qwen models |
| Groq | `https://api.groq.com/openai/v1` | Llama models |
| Together | `https://api.together.xyz/v1` | Various models |

### Local/Self-hosted

| Provider | Base URL | Notes |
|----------|----------|-------|
| Ollama | `http://localhost:11434/v1` | Local models |
| LM Studio | `http://localhost:1234/v1` | Local models |

### Special APIs

| Provider | Base URL | Notes |
|----------|----------|-------|
| Anthropic | `https://api.anthropic.com/v1` | Claude models |
| Google Gemini | `https://generativelanguage.googleapis.com/v1beta` | Gemini models |

## Configuration

### Swift Layer

```swift
@Published var isRefinementEnabled: Bool
@Published var selectedProvider: AIProvider
@Published var baseURL: String
@Published var model: String
@Published var customPrompt: String
```

### API Key Storage

API keys are stored securely in macOS Keychain:

```swift
private let keychainService = "com.whisper-dictation.refinement"
private let keychainAccount = "api-key"

func saveAPIKey(_ key: String) -> Bool {
    // Store in Keychain
}

func getAPIKey() -> String? {
    // Retrieve from Keychain
}
```

### Configuration Export

Swift exports configuration to Python via environment variables:

```swift
func exportConfig() -> [String: String] {
    var config: [String: String] = [:]
    config["DICTATE_REFINEMENT_ENABLED"] = isRefinementEnabled ? "true" : "false"
    config["DICTATE_REFINEMENT_PROVIDER"] = selectedProvider.rawValue
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
    provider = os.environ.get("DICTATE_REFINEMENT_PROVIDER")
    base_url = os.environ.get("DICTATE_REFINEMENT_BASE_URL")
    model = os.environ.get("DICTATE_REFINEMENT_MODEL")
    api_key = os.environ.get("DICTATE_REFINEMENT_API_KEY")
    prompt = os.environ.get("DICTATE_REFINEMENT_PROMPT")

    text = refine_with_api(text, provider, base_url, model, api_key, prompt)
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

## Provider Presets

Each provider has default settings:

```swift
struct ProviderPreset {
    let name: String
    let baseURL: String
    let defaultModel: String
    let popularModels: [String]
}

// Example: OpenAI
ProviderPreset(
    name: "OpenAI",
    baseURL: "https://api.openai.com/v1",
    defaultModel: "gpt-4o-mini",
    popularModels: ["gpt-4o", "gpt-4o-mini", "o3"]
)
```

## Cross-References

- [Transcription](transcription.md) - What gets refined
- [Python Guide](../python-guide.md) - Environment variables
- [Configuration](../api/configuration.md) - All configuration options

---

*Last updated: 2026-03-24*
