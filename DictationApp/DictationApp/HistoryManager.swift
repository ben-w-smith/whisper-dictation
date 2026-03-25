import Foundation

/// Manages local transcription history storage
/// Stores the last 1000 transcriptions in a JSON file in Application Support
@MainActor
class HistoryManager: ObservableObject {
    static let shared = HistoryManager()

    // MARK: - Published State

    @Published var transcriptions: [Transcription] = []

    // MARK: - Configuration

    private let maxTranscriptions = 1000
    private let historyFileName = "transcription_history.json"

    // MARK: - Computed Properties

    private var historyFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("DictationApp")

        // Ensure directory exists
        if !FileManager.default.fileExists(atPath: appDir.path) {
            try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        }

        return appDir.appendingPathComponent(historyFileName)
    }

    // MARK: - Initialization

    private init() {
        loadHistory()
    }

    // MARK: - Public Methods

    /// Add a new transcription to history
    func addTranscription(_ transcription: Transcription) {
        // Add to beginning (most recent first)
        transcriptions.insert(transcription, at: 0)

        // Trim to max size
        if transcriptions.count > maxTranscriptions {
            transcriptions = Array(transcriptions.prefix(maxTranscriptions))
        }

        saveHistory()
    }

    /// Clear all history
    func clearHistory() {
        transcriptions = []
        saveHistory()
    }

    /// Reload history from disk
    func reloadHistory() {
        loadHistory()
    }

    // MARK: - Private Methods

    private func loadHistory() {
        guard FileManager.default.fileExists(atPath: historyFileURL.path),
              let data = try? Data(contentsOf: historyFileURL),
              let decoded = try? JSONDecoder().decode([Transcription].self, from: data) else {
            transcriptions = []
            return
        }

        transcriptions = decoded
        print("Loaded \(transcriptions.count) transcriptions from local history")
    }

    private func saveHistory() {
        guard let data = try? JSONEncoder().encode(transcriptions) else {
            print("Failed to encode transcriptions")
            return
        }

        do {
            try data.write(to: historyFileURL, options: .atomic)
            print("Saved \(transcriptions.count) transcriptions to local history")
        } catch {
            print("Failed to save history: \(error)")
        }
    }
}
