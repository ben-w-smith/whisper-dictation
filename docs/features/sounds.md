# Sound Effects

Audio feedback configuration in DictationApp.

## Overview

SoundManager provides audio feedback for recording events using macOS system sounds.

## Available Sounds

| Sound | Description |
|-------|-------------|
| None | No sound |
| Ping | Soft ping |
| Glass | Glass clink |
| Pop | Pop sound |
| Funk | Funky tone |
| Hero | Heroic fanfare |
| Submarine | Sonar ping |
| Bottle | Bottle pop |
| Frog | Frog ribbit |
| Morse | Morse code beep |
| Purr | Cat purr |
| Blow | Blow sound |
| Tink | Tink sound |

## Sound Events

| Event | Default Sound | When |
|-------|---------------|------|
| Start Recording | Glass | When recording begins |
| Stop Recording | Pop | When recording ends |
| Transcription Ready | Hero | When transcription completes |

## Configuration

### Swift Model

```swift
enum SoundEffect: String, CaseIterable, Codable {
    case none = "None"
    case ping = "Ping"
    case glass = "Glass"
    case pop = "Pop"
    // ...
}

struct SoundConfiguration: Codable {
    var startRecording: SoundEffect = .glass
    var stopRecording: SoundEffect = .pop
    var transcriptionReady: SoundEffect = .hero
}
```

### Manager Properties

```swift
@Published var soundsEnabled: Bool  // Master toggle
@Published var soundVolume: Double  // 0.0 to 1.0
@Published var configuration: SoundConfiguration
```

## Playback

Sounds are played via NSSound:

```swift
func playStartRecording() {
    guard soundsEnabled else { return }
    playSound(configuration.startRecording)
}

private func playSound(_ sound: SoundEffect) {
    guard !sound.isNone else { return }

    if let nsSound = NSSound(named: NSSound.Name(sound.rawValue)) {
        nsSound.volume = Float(soundVolume)
        nsSound.play()
    }
}
```

## Persistence

Configuration is stored in UserDefaults:

```swift
private func saveConfiguration() {
    if let data = try? JSONEncoder().encode(configuration) {
        UserDefaults.standard.set(data, forKey: "soundConfiguration")
    }
}
```

## UI Integration

### Preview

Users can preview sounds before selecting:

```swift
func previewSound(_ sound: SoundEffect) {
    playSound(sound)
}
```

### Settings View

The SoundSettingsView provides:
- Master enable/disable toggle
- Volume slider
- Sound picker for each event
- Preview buttons

## Usage in Recording Flow

```swift
// In TranscriptionManager
func startRecording() {
    SoundManager.shared.playStartRecording()
    // ...
}

func stopRecording() {
    SoundManager.shared.playStopRecording()
    // ... processing ...
    SoundManager.shared.playTranscriptionReady()
}
```

## Cross-References

- [Recording](recording.md) - When sounds are triggered
- [Swift Guide](../swift-guide.md) - SoundManager implementation

---

*Last updated: 2026-03-24*
