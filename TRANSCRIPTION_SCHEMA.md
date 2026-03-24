# Transcription Storage Schema

## Location
`/Users/bensmith/ObsidianVault/Default/transcriptions/`

## File Naming
`YYYY-MM-DD HH-MM-SS.md`

Example: `2026-03-23 17-30-45.md`

## File Format
Markdown with YAML frontmatter:

```markdown
---
created: 2026-03-23T17:30:45.123456
model: tiny.en
---

The transcribed text goes here...
```

## Fields

| Field | Type | Description |
|-------|------|-------------|
| `created` | ISO 8601 datetime | When the transcription was created |
| `model` | string | The Whisper model used (e.g., `tiny.en`, `distil-large-v3`) |
| Body | markdown | The transcribed (and Gemini-processed) text |

## Behavior

- **Blank transcriptions**: Not saved (no file created)
- **Sync**: Handled by Obsidian's existing sync mechanism
- **Access**: Can be viewed in Obsidian or via the native app's history UI

## Future Extensions

When the native app is built, additional fields could be added:
- `duration`: Length of the original audio
- `device`: Which microphone was used
- `gemini_processed`: Boolean indicating if Gemini post-processing was applied
