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
    let duration: Double  // Audio duration in seconds
    let wordCount: Int
    let wpm: Double  // Words per minute

    init(id: UUID = UUID(), text: String, timestamp: Date = Date(), model: WhisperModel, duration: Double = 0, wordCount: Int = 0, wpm: Double = 0) {
        self.id = id
        self.text = text
        self.timestamp = timestamp
        self.model = model
        self.duration = duration
        self.wordCount = wordCount > 0 ? wordCount : Self.countWords(in: text)
        self.wpm = wpm > 0 ? wpm : Self.calculateWpm(wordCount: wordCount, duration: duration)
    }

    /// Count words in text
    static func countWords(in text: String) -> Int {
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        return words.filter { !$0.isEmpty }.count
    }

    /// Calculate WPM from word count and duration
    static func calculateWpm(wordCount: Int, duration: Double) -> Double {
        guard duration > 0 else { return 0 }
        return Double(wordCount) / (duration / 60.0)
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
        var duration: Double = 0
        var wordCount: Int = 0
        var wpm: Double = 0

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
                } else if line.hasPrefix("duration:") {
                    let value = line.replacingOccurrences(of: "duration:", with: "").trimmingCharacters(in: .whitespaces)
                    duration = Double(value) ?? 0
                } else if line.hasPrefix("word_count:") {
                    let value = line.replacingOccurrences(of: "word_count:", with: "").trimmingCharacters(in: .whitespaces)
                    wordCount = Int(value) ?? 0
                } else if line.hasPrefix("wpm:") {
                    let value = line.replacingOccurrences(of: "wpm:", with: "").trimmingCharacters(in: .whitespaces)
                    wpm = Double(value) ?? 0
                }
            } else if pastFrontmatter {
                textLines.append(line)
            }
        }

        let text = textLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)

        guard !text.isEmpty,
              let model = WhisperModel(rawValue: modelName ?? "tiny.en")
        else { return nil }

        // Calculate word count if not stored
        if wordCount == 0 {
            wordCount = countWords(in: text)
        }

        // Calculate WPM if not stored but we have duration
        if wpm == 0 && duration > 0 {
            wpm = calculateWpm(wordCount: wordCount, duration: duration)
        }

        return Transcription(
            id: UUID(),
            text: text,
            timestamp: created ?? Date(),
            model: model,
            duration: duration,
            wordCount: wordCount,
            wpm: wpm
        )
    }
}
