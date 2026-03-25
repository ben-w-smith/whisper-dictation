# Refinement

AI post-processing for transcriptions in DictationApp.

## Overview

Refinement allows AI models to improve raw Whisper transcriptions by fixing grammar, punctuation, and removing filler words. Supports multiple API patterns for maximum compatibility.

## API Patterns

DictationApp supports three API patterns:

| Pattern | Description | Providers |
|---------|-------------|-----------|
| **OpenAI-compatible** | Standard OpenAI chat completions format | OpenAI, DeepSeek, Moonshot, Groq, Qwen, OpenRouter, Ollama, LM Studio |
| **Anthropic/Claude** | Anthropic Messages API format | Anthropic Claude |
| **Google Gemini** | Google Generative AI format | Google Gemini |

## Configuration

### Swift Layer

```swift
@Published var isRefinementEnabled: Bool
@Published var apiPattern: APIPattern  // .openAI, .anthropic, or .gemini
@Published var baseURL: String
@Published var model: String
@Published var customPrompt: String
```

### UI Fields

- **API Pattern**: Dropdown selecting the API format
- **Base URL**: API endpoint (pre-filled with pattern default, editable)
- **Model**: Model name (free-form text)
- **API Key**: Stored securely in macOS Keychain

### Popular Providers

The UI includes a collapsible "Popular Providers" section with pre-configured URLs. Click "Use" to auto-fill the base URL and a suggested model.

### Configuration Export

Swift exports configuration to Python via environment variables:

```swift
func exportConfig() -> [String: String] {
    config["DICTATE_REFINEMENT_ENABLED"] = isRefinementEnabled ? "true" : "false"
    config["DICTATE_REFINEMENT_API_PATTERN"] = apiPattern.rawValue  // "openai", "anthropic", or "gemini"
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

The Python script routes to different handlers based on the API pattern:

```python
REFINEMENT_API_PATTERN = os.environ.get("DICTATE_REFINEMENT_API_PATTERN", "openai")

def refine_transcription(text: str) -> str:
    if REFINEMENT_API_PATTERN == "anthropic":
        return refine_with_anthropic(text)
    elif REFINEMENT_API_PATTERN == "gemini":
        return refine_with_gemini(text)
    else:
        return refine_with_openai_compatible(text)
```

### Pattern-Specific Details

#### OpenAI-compatible
- Endpoint: `POST /chat/completions`
- Auth: `Authorization: Bearer <api-key>`
- Response: `choices[0].message.content`

#### Anthropic/Claude
- Endpoint: `POST /messages`
- Auth: `x-api-key: <api-key>`, `anthropic-version: 2023-06-01`
- Requires `max_tokens` parameter
- Response: `content[0].text`

#### Google Gemini
- Endpoint: `POST /models/{model}:generateContent`
- Auth: `x-goog-api-key: <api-key>`
- Model name in URL path
- Response: `candidates[0].content.parts[0].text`

## Error Handling

If refinement fails, the raw transcription is used:

```python
try:
    refined = refine_transcription(text)
except Exception as e:
    print(f"Refinement failed: {e}")
    refined = text  # Fall back to raw
```

## Updating Provider List

Provider examples are stored in `DictationApp/Resources/providers.json`. To add or update providers:

1. Edit `providers.json` with new provider info
2. Submit a pull request

The JSON structure:
```json
{
  "providers": [
    {
      "name": "Provider Name",
      "pattern": "openai",
      "baseURL": "https://api.example.com/v1",
      "models": ["model-1", "model-2"],
      "docsURL": "https://docs.example.com",
      "apiKeyURL": "https://example.com/keys"
    }
  ]
}
```

## Cross-References

- [Transcription](transcription.md) - What gets refined
- [Python Guide](../python-guide.md) - Environment variables
- [Configuration](../api/configuration.md) - All configuration options

---

*Last updated: 2026-03-25*
