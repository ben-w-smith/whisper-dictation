import Foundation
import CoreAudio

// MARK: - Audio Device

struct AudioDevice: Identifiable, Equatable, Hashable, Codable {
    let id: Int  // PyAudio device index (-1 for system default)
    let name: String
    let isDefault: Bool

    var displayName: String {
        if id == -1 {
            return "System Default"
        }
        return name
    }

    static let systemDefault = AudioDevice(id: -1, name: "System Default", isDefault: true)
}

// MARK: - Whisper Model

enum WhisperModel: String, CaseIterable, Identifiable, Codable {
    case tinyEn = "tiny.en"
    case baseEn = "base.en"
    case distilSmallEn = "distil-small.en"
    case distilMediumEn = "distil-medium.en"
    case distilLargeV3 = "distil-large-v3"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .tinyEn: return "Tiny (Fastest)"
        case .baseEn: return "Base"
        case .distilSmallEn: return "Distil Small"
        case .distilMediumEn: return "Distil Medium"
        case .distilLargeV3: return "Distil Large v3 (Best)"
        }
    }

    var speed: String {
        switch self {
        case .tinyEn: return "~40x realtime"
        case .baseEn: return "~30x realtime"
        case .distilSmallEn: return "~20x realtime"
        case .distilMediumEn: return "~7x realtime"
        case .distilLargeV3: return "~6x realtime"
        }
    }
}

struct Transcription: Identifiable, Codable {
    let id: UUID
    let text: String
    let timestamp: Date
    let model: WhisperModel

    init(id: UUID = UUID(), text: String, timestamp: Date = Date(), model: WhisperModel) {
        self.id = id
        self.text = text
        self.timestamp = timestamp
        self.model = model
    }
}

// MARK: - Obsidian File Parsing

extension Transcription {
    /// Parse a transcription from an Obsidian markdown file
    static func fromObsidianFile(url: URL) -> Transcription? {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }

        // Parse frontmatter
        var created: Date?
        var modelName: String?

        // Simple frontmatter parsing
        let lines = content.components(separatedBy: "\n")
        var inFrontmatter = false
        var textLines: [String] = []
        var pastFrontmatter = false

        for line in lines {
            if line == "---" {
                if !inFrontmatter {
                    inFrontmatter = true
                    continue
                } else {
                    inFrontmatter = false
                    pastFrontmatter = true
                    continue
                }
            }

            if inFrontmatter {
                if line.hasPrefix("created:") {
                    let value = line.replacingOccurrences(of: "created:", with: "").trimmingCharacters(in: .whitespaces)
                    created = ISO8601DateFormatter().date(from: value)
                } else if line.hasPrefix("model:") {
                    modelName = line.replacingOccurrences(of: "model:", with: "").trimmingCharacters(in: .whitespaces)
                }
            } else if pastFrontmatter {
                textLines.append(line)
            }
        }

        let text = textLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)

        guard !text.isEmpty,
              let model = WhisperModel(rawValue: modelName ?? "tiny.en")
        else { return nil }

        return Transcription(
            id: UUID(),
            text: text,
            timestamp: created ?? Date(),
            model: model
        )
    }
}
