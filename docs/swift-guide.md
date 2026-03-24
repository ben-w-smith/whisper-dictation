# Swift Guide

Patterns, conventions, and key classes in the DictationApp Swift application.

## Project Structure

```
DictationApp/
+-- Package.swift                # Swift Package Manager config
+-- DictationApp/
|   +-- DictationApp.swift       # App entry point (MenuBarExtra)
|   +-- ContentView.swift        # Main UI (recording controls, history)
|   +-- TranscriptionManager.swift  # Central state coordinator
|   +-- Models.swift             # Data models (WhisperModel, Transcription)
|   +-- AutoPasteManager.swift   # Accessibility API auto-paste
|   +-- StatisticsManager.swift  # Usage tracking
|   +-- RefinementManager.swift  # AI post-processing config
|   +-- ObsidianManager.swift    # Vault path configuration
|   +-- SoundManager.swift       # Sound effect playback
|   +-- GlobalHotkey.swift       # KeyboardShortcuts integration
```

## Core Patterns

### @MainActor Isolation

All managers are `@MainActor` isolated to ensure UI updates happen on the main thread:

```swift
@MainActor
class TranscriptionManager: ObservableObject {
    @Published var isRecording = false
    // ...
}
```

### @StateObject vs @EnvironmentObject

Managers are created as `@StateObject` at the app level and passed as `@EnvironmentObject` to views:

```swift
@main
struct DictationApp: App {
    @StateObject private var transcriptionManager = TranscriptionManager()

    var body: some Scene {
        MenuBarExtra("Dictation", systemImage: ...) {
            ContentView()
                .environmentObject(transcriptionManager)
        }
    }
}
```

### Singleton Pattern for Managers

Managers use the singleton pattern for global access:

```swift
@MainActor
class AutoPasteManager: ObservableObject {
    static let shared = AutoPasteManager()
    private init() { ... }
}
```

### UserDefaults Persistence

Settings are persisted via `UserDefaults` with `didSet` observers:

```swift
@Published var isEnabled: Bool {
    didSet {
        UserDefaults.standard.set(isEnabled, forKey: "autoPasteEnabled")
    }
}
```

## Key Classes

### TranscriptionManager

Central coordinator for all operations.

**Responsibilities:**
- Recording state management (`isRecording`)
- Model selection and warmup
- Loading transcriptions from Obsidian vault
- Python script execution via `Process` API
- Audio device enumeration

**Key Methods:**
- `toggleRecording()` - Start/stop recording
- `runPythonScript(name:)` - Execute Python scripts
- `loadTranscriptions()` - Read from Obsidian vault
- `warmupModel()` - Pre-load model on startup

### Models.swift

Data models for the application.

```swift
enum WhisperModel: String, CaseIterable {
    case tinyEn = "tiny.en"
    case baseEn = "base.en"
    case smallEn = "small.en"
    case distilLargeV3 = "distil-large-v3"
    // ...
}

struct Transcription: Identifiable {
    let id: UUID
    let text: String
    let timestamp: Date
    let model: WhisperModel
}
```

### AutoPasteManager

Handles automatic text insertion via Accessibility API.

**Key Features:**
- Records focused element when recording starts
- Direct text insertion via `AXUIElementSetAttributeValue`
- Fallback to Cmd+V simulation
- Permission monitoring for Accessibility access

### GlobalHotkey

Uses KeyboardShortcuts SPM package for global hotkey support.

```swift
extension KeyboardShortcuts.Name {
    static let toggleDictation = Self(
        "toggleDictation",
        default: .init(.space, modifiers: .control)
    )
}
```

## Python Script Execution

Swift executes Python scripts using the `Process` API:

```swift
private func runPythonScript(name: String) async throws -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: venvPython)
    process.arguments = [scriptPath]

    // Pass configuration as environment variables
    var environment = ProcessInfo.processInfo.environment
    for (key, value) in RefinementManager.shared.exportConfig() {
        environment[key] = value
    }
    process.environment = environment

    try process.run()
    process.waitUntilExit()
    // ...
}
```

## Code Modification Pattern

The Swift app modifies Python scripts directly to change settings:

```swift
let pattern = #"MODEL_SIZE = "[^"]+""#
let replacement = #"MODEL_SIZE = "\#(selectedModel.rawValue)""#
// ... regex replacement in dictate-toggle.py
```

## Cross-References

- [Architecture](architecture.md) - System overview
- [Auto-Paste](features/auto-paste.md) - AutoPasteManager details
- [Statistics](features/statistics.md) - StatisticsManager details
- [Refinement](features/refinement.md) - RefinementManager details

---

*Last updated: 2026-03-24*
