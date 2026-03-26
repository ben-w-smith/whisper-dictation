import Foundation

// MARK: - Transcription Provider

/// Represents the transcription provider (local Whisper or remote Gemini)
enum TranscriptionProvider: String, CaseIterable, Identifiable, Codable {
    case local = "local"
    case geminiLite = "gemini-lite"      // Gemini 3.1 Flash Lite
    case geminiFlash = "gemini-flash"    // Gemini 3 Flash

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .local: return "Local Whisper (Free, Offline)"
        case .geminiLite: return "Gemini 3.1 Flash Lite (Free tier)"
        case .geminiFlash: return "Gemini 3 Flash (Free tier)"
        }
    }

    var shortName: String {
        switch self {
        case .local: return "Local Whisper"
        case .geminiLite: return "Gemini Lite"
        case .geminiFlash: return "Gemini Flash"
        }
    }

    /// The model name used by the Gemini API
    var geminiModelName: String {
        switch self {
        case .local: return ""
        case .geminiLite: return "gemini-3.1-flash-lite-preview"
        case .geminiFlash: return "gemini-3-flash-preview"
        }
    }

    var isRemote: Bool {
        self != .local
    }

    var description: String {
        switch self {
        case .local: return "On-device transcription using faster-whisper. No internet required."
        case .geminiLite: return "Fast, cost-efficient cloud transcription. Free tier: 1,500 requests/day."
        case .geminiFlash: return "High-quality cloud transcription. Free tier: 1,500 requests/day."
        }
    }

    var iconName: String {
        switch self {
        case .local: return "cpu"
        case .geminiLite: return "cloud"
        case .geminiFlash: return "sparkles"
        }
    }
}
