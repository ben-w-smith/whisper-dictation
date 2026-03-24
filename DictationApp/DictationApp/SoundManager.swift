import Foundation
import AppKit

// MARK: - Sound Configuration

enum SoundEffect: String, CaseIterable, Identifiable, Codable {
    case none = "None"
    case ping = "Ping"
    case glass = "Glass"
    case pop = "Pop"
    case funk = "Funk"
    case hero = "Hero"
    case submarine = "Submarine"
    case bottle = "Bottle"
    case frog = "Frog"
    case morse = "Morse"
    case purr = "Purr"
    case blow = "Blow"
    case tink = "Tink"

    var id: String { rawValue }

    var displayName: String { rawValue }

    var isNone: Bool { self == .none }

    func play() {
        guard !isNone else { return }
        NSSound(named: NSSound.Name(rawValue))?.play()
    }

    static func play(_ sound: SoundEffect) {
        sound.play()
    }
}

// MARK: - Sound Event Configuration

struct SoundConfiguration: Codable {
    var startRecording: SoundEffect = .glass
    var stopRecording: SoundEffect = .pop
    var transcriptionReady: SoundEffect = .hero

    static let `default` = SoundConfiguration()
}

// MARK: - Sound Manager

@MainActor
class SoundManager: ObservableObject {
    static let shared = SoundManager()

    // MARK: - Published Properties

    @Published var soundsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(soundsEnabled, forKey: "soundsEnabled")
        }
    }

    @Published var soundVolume: Double {
        didSet {
            UserDefaults.standard.set(soundVolume, forKey: "soundVolume")
        }
    }

    @Published var configuration: SoundConfiguration {
        didSet {
            saveConfiguration()
        }
    }

    // MARK: - Computed Properties

    var startRecordingSound: SoundEffect {
        get { configuration.startRecording }
        set {
            configuration.startRecording = newValue
            saveConfiguration()
        }
    }

    var stopRecordingSound: SoundEffect {
        get { configuration.stopRecording }
        set {
            configuration.stopRecording = newValue
            saveConfiguration()
        }
    }

    var transcriptionReadySound: SoundEffect {
        get { configuration.transcriptionReady }
        set {
            configuration.transcriptionReady = newValue
            saveConfiguration()
        }
    }

    // MARK: - Initialization

    private init() {
        // Initialize configuration first (required for all stored properties)
        self.configuration = Self.loadConfiguration()

        self.soundsEnabled = UserDefaults.standard.bool(forKey: "soundsEnabled")
        // Default to true if not set (key doesn't exist)
        if !UserDefaults.standard.bool(forKey: "hasInitializedSoundsEnabled") {
            self.soundsEnabled = true
            UserDefaults.standard.set(true, forKey: "hasInitializedSoundsEnabled")
        }

        self.soundVolume = UserDefaults.standard.double(forKey: "soundVolume")
        if self.soundVolume == 0 {
            self.soundVolume = 1.0
        }
    }

    // MARK: - Persistence

    private func saveConfiguration() {
        if let data = try? JSONEncoder().encode(configuration) {
            UserDefaults.standard.set(data, forKey: "soundConfiguration")
        }
    }

    private static func loadConfiguration() -> SoundConfiguration {
        guard let data = UserDefaults.standard.data(forKey: "soundConfiguration"),
              let config = try? JSONDecoder().decode(SoundConfiguration.self, from: data) else {
            return .default
        }
        return config
    }

    // MARK: - Sound Playback

    func playStartRecording() {
        guard soundsEnabled else { return }
        playSound(configuration.startRecording)
    }

    func playStopRecording() {
        guard soundsEnabled else { return }
        playSound(configuration.stopRecording)
    }

    func playTranscriptionReady() {
        guard soundsEnabled else { return }
        playSound(configuration.transcriptionReady)
    }

    private func playSound(_ sound: SoundEffect) {
        guard !sound.isNone else { return }

        // Run on main thread to avoid issues
        Task { @MainActor in
            if let nsSound = NSSound(named: NSSound.Name(sound.rawValue)) {
                nsSound.volume = Float(soundVolume)
                nsSound.play()
            }
        }
    }

    func previewSound(_ sound: SoundEffect) {
        playSound(sound)
    }
}
