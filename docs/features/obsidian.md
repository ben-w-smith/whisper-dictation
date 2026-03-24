# Obsidian Integration

Vault connection and file management in DictationApp.

## Overview

DictationApp saves transcriptions as markdown files in an Obsidian vault, providing automatic backup, search, and organization through Obsidian's features.

## Vault Configuration

### Requirements

- A valid Obsidian vault (folder containing `.obsidian` subfolder)
- Write permissions to the vault

### Swift Configuration

```swift
class ObsidianManager: ObservableObject {
    @Published var isVaultEnabled: Bool
    @Published var vaultPath: URL?
    @Published var validationStatus: VaultStatus
}
```

### Vault Selection

```swift
func selectVaultFolder() {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.message = "Select your Obsidian vault folder"

    panel.begin { response in
        guard response == .OK, let url = panel.url else { return }
        self.vaultPath = url
    }
}
```

## Validation

The manager validates the vault:

1. **Path exists** as a directory
2. **Contains `.obsidian` folder** (required for valid vault)
3. **Can create `transcriptions` directory**
4. **Has write permissions**

```swift
func validateVault() {
    // Check path exists
    guard FileManager.default.fileExists(atPath: path.path) else {
        validationStatus = .invalid("Folder does not exist")
        return
    }

    // Check for .obsidian folder
    let obsidianFolder = path.appendingPathComponent(".obsidian")
    guard FileManager.default.fileExists(atPath: obsidianFolder.path) else {
        validationStatus = .invalid("Not an Obsidian vault")
        return
    }

    // Create transcriptions directory if needed
    let transcriptionsDir = path.appendingPathComponent("transcriptions")
    try FileManager.default.createDirectory(at: transcriptionsDir, ...)

    validationStatus = .valid
}
```

## File Format

Transcriptions are saved as markdown files with YAML frontmatter:

```markdown
---
date: 2026-03-24T15:30:00Z
model: tiny.en
duration: 12.5
---

This is the transcribed text content.
```

## Transcription Path

The full path to transcriptions:

```swift
var transcriptionsPath: String? {
    guard isVaultEnabled, let vault = vaultPath else { return nil }
    return vault.appendingPathComponent("transcriptions").path
}
```

## Python Integration

The vault path is written to `dictate-toggle.py`:

```python
OBSIDIAN_VAULT = Path("/Users/bensmith/ObsidianVault/Default")
```

Swift updates this value before calling the script:

```swift
func updatePythonScript() -> Bool {
    let pattern = #"OBSIDIAN_VAULT = Path\("[^"]+"\)"#
    let replacement = #"OBSIDIAN_VAULT = Path("\#(vaultPath.path)")"#
    // Regex replacement
}
```

## Loading History

Swift loads transcriptions from the vault for display:

```swift
func loadTranscriptions() {
    guard let transcriptionsPath = obsidianManager.transcriptionsPath else { return }

    let files = try FileManager.default.contentsOfDirectory(at: url, ...)
    let markdownFiles = files.filter { $0.pathExtension == "md" }

    transcriptions = markdownFiles.compactMap { Transcription.fromObsidianFile(url: $0) }
}
```

## Status Types

```swift
enum VaultStatus: Equatable {
    case notConfigured
    case valid
    case invalid(String)
    case checking
}
```

## Disabling Vault

If vault is disabled:
- Transcriptions are not saved to disk
- History will not be available
- Statistics will not persist across sessions

## Cross-References

- [Architecture](../architecture.md) - Data flow diagram
- [Python Guide](../python-guide.md) - Python file saving
- [Swift Guide](../swift-guide.md) - ObsidianManager implementation

---

*Last updated: 2026-03-24*
