import Foundation
import SwiftUI

// MARK: - Achievement

struct Achievement: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let description: String
    let icon: String
    let threshold: Int // e.g., word count or streak days

    static let thousandWords = Achievement(
        id: "1000_words",
        title: "Word Collector",
        description: "Transcribe 1,000 words",
        icon: "text.bubble.fill",
        threshold: 1000
    )

    static let tenThousandWords = Achievement(
        id: "10000_words",
        title: "Prolific Writer",
        description: "Transcribe 10,000 words",
        icon: "text.book.closed.fill",
        threshold: 10000
    )

    static let sevenDayStreak = Achievement(
        id: "7_day_streak",
        title: "Week Warrior",
        description: "7-day transcription streak",
        icon: "flame.fill",
        threshold: 7
    )

    static let thirtyDayStreak = Achievement(
        id: "30_day_streak",
        title: "Monthly Master",
        description: "30-day transcription streak",
        icon: " crown.fill",
        threshold: 30
    )

    static let allAchievements: [Achievement] = [
        .thousandWords, .tenThousandWords, .sevenDayStreak, .thirtyDayStreak
    ]
}

// MARK: - Statistics Data

struct StatisticsData: Codable {
    var totalWords: Int = 0
    var totalSessions: Int = 0
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var wordsToday: Int = 0
    var wordsThisWeek: Int = 0
    var wordsThisMonth: Int = 0
    var modelUsage: [String: Int] = [:] // model name -> count
    var totalRecordingSeconds: Double = 0
    var mostProductiveDay: Date?
    var mostProductiveDayWords: Int = 0
    var unlockedAchievements: Set<String> = []
    var lastActiveDate: Date?

    // For tracking daily word counts
    var dailyWordCounts: [String: Int] = [:] // "YYYY-MM-DD" -> word count
}

// MARK: - Statistics Manager

@MainActor
class StatisticsManager: ObservableObject {
    static let shared = StatisticsManager()

    @Published private(set) var data: StatisticsData {
        didSet {
            saveData()
        }
    }

    @Published private(set) var averageWpm: Double = 0

    private let userDefaultsKey = "dictationStatistics"

    private init() {
        // Initialize with empty data first, then load
        self.data = StatisticsData()
        self.data = loadData()
        recalculateStats()
    }

    // MARK: - Persistence

    private func loadData() -> StatisticsData {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let stats = try? JSONDecoder().decode(StatisticsData.self, from: data) else {
            return StatisticsData()
        }
        return stats
    }

    private func saveData() {
        guard let encoded = try? JSONEncoder().encode(data) else { return }
        UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
    }

    // MARK: - Public API

    /// Update statistics from a list of transcriptions
    func updateFromTranscriptions(_ transcriptions: [Transcription]) {
        resetDailyCounts()
        calculateFromTranscriptions(transcriptions)
        recalculateStats()
        checkAchievements()
    }

    /// Record a new transcription
    func recordTranscription(_ transcription: Transcription) {
        let wordCount = countWords(in: transcription.text)
        let today = Calendar.current.startOfDay(for: Date())
        let todayKey = dateKey(today)

        // Update totals
        data.totalWords += wordCount
        data.totalSessions += 1

        // Update daily counts
        data.dailyWordCounts[todayKey, default: 0] += wordCount
        data.wordsToday = data.dailyWordCounts[todayKey, default: 0]

        // Update model usage
        let modelName = transcription.model.rawValue
        data.modelUsage[modelName, default: 0] += 1

        // Update last active date
        data.lastActiveDate = Date()

        // Recalculate streak
        calculateStreak()

        // Update weekly/monthly counts
        recalculateWeeklyMonthly()

        // Check if this is the most productive day
        if data.dailyWordCounts[todayKey, default: 0] > data.mostProductiveDayWords {
            data.mostProductiveDay = today
            data.mostProductiveDayWords = data.dailyWordCounts[todayKey, default: 0]
        }

        // Check achievements
        checkAchievements()
    }

    /// Get formatted summary for menu bar display
    var compactSummary: String {
        let wordsFormatted = formatNumber(data.totalWords)
        return "\(wordsFormatted) words | \(data.currentStreak) day streak"
    }

    /// Get all unlocked achievements
    var unlockedAchievementsList: [Achievement] {
        Achievement.allAchievements.filter { data.unlockedAchievements.contains($0.id) }
    }

    /// Get locked achievements
    var lockedAchievements: [Achievement] {
        Achievement.allAchievements.filter { !data.unlockedAchievements.contains($0.id) }
    }

    // MARK: - Calculation Methods

    private func calculateFromTranscriptions(_ transcriptions: [Transcription]) {
        // Reset counts
        data.totalWords = 0
        data.totalSessions = transcriptions.count
        data.dailyWordCounts = [:]
        data.modelUsage = [:]

        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now

        var mostProductiveDate: Date?
        var mostProductiveCount = 0

        for transcription in transcriptions {
            let wordCount = countWords(in: transcription.text)
            data.totalWords += wordCount

            // Track by day
            let dayKey = dateKey(transcription.timestamp)
            data.dailyWordCounts[dayKey, default: 0] += wordCount

            // Track model usage
            let modelName = transcription.model.rawValue
            data.modelUsage[modelName, default: 0] += 1

            // Update last active date
            if data.lastActiveDate == nil || transcription.timestamp > data.lastActiveDate! {
                data.lastActiveDate = transcription.timestamp
            }
        }

        // Calculate today, this week, this month
        let todayKey = dateKey(startOfToday)
        data.wordsToday = data.dailyWordCounts[todayKey, default: 0]

        // Calculate this week
        data.wordsThisWeek = 0
        for (dateStr, count) in data.dailyWordCounts {
            if let date = dateFromKey(dateStr), date >= startOfWeek {
                data.wordsThisWeek += count
            }
        }

        // Calculate this month
        data.wordsThisMonth = 0
        for (dateStr, count) in data.dailyWordCounts {
            if let date = dateFromKey(dateStr), date >= startOfMonth {
                data.wordsThisMonth += count
            }
        }

        // Find most productive day
        for (dateStr, count) in data.dailyWordCounts {
            if count > mostProductiveCount {
                mostProductiveCount = count
                mostProductiveDate = dateFromKey(dateStr)
            }
        }
        data.mostProductiveDay = mostProductiveDate
        data.mostProductiveDayWords = mostProductiveCount

        // Calculate streak
        calculateStreak()
    }

    private func calculateStreak() {
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        var streak = 0
        var checkDate = today

        // Check if there's activity today
        let todayKey = dateKey(today)
        let yesterdayKey = dateKey(yesterday)

        // Start counting from today if there's activity, otherwise from yesterday
        if data.dailyWordCounts[todayKey, default: 0] > 0 {
            streak = 1
            checkDate = yesterday
        } else if data.dailyWordCounts[yesterdayKey, default: 0] > 0 {
            streak = 0
            checkDate = yesterday
        } else {
            // No recent activity
            data.currentStreak = 0
            return
        }

        // Count consecutive days backwards
        while true {
            let dateKey = self.dateKey(checkDate)
            if data.dailyWordCounts[dateKey, default: 0] > 0 {
                streak += 1
                guard let nextDate = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
                checkDate = nextDate
            } else {
                break
            }
        }

        data.currentStreak = streak

        // Update longest streak
        if streak > data.longestStreak {
            data.longestStreak = streak
        }
    }

    private func recalculateStats() {
        recalculateWeeklyMonthly()

        // Calculate average WPM (assuming average speaking rate of 150 wpm for recording time estimation)
        if data.totalWords > 0 && data.totalRecordingSeconds > 0 {
            averageWpm = Double(data.totalWords) / (data.totalRecordingSeconds / 60.0)
        } else {
            // Use a reasonable estimate based on total sessions
            averageWpm = 120 // Default estimate
        }
    }

    private func recalculateWeeklyMonthly() {
        let calendar = Calendar.current
        let now = Date()
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now

        data.wordsThisWeek = 0
        data.wordsThisMonth = 0

        for (dateStr, count) in data.dailyWordCounts {
            if let date = dateFromKey(dateStr) {
                if date >= startOfWeek {
                    data.wordsThisWeek += count
                }
                if date >= startOfMonth {
                    data.wordsThisMonth += count
                }
            }
        }
    }

    private func resetDailyCounts() {
        // Clean up old entries (keep last 365 days)
        let calendar = Calendar.current
        let cutoffDate = calendar.date(byAdding: .day, value: -365, to: Date())!
        let cutoffKey = dateKey(cutoffDate)

        data.dailyWordCounts = data.dailyWordCounts.filter { key, _ in
            key >= cutoffKey
        }
    }

    private func checkAchievements() {
        // Check word count achievements
        if data.totalWords >= 1000 {
            data.unlockedAchievements.insert(Achievement.thousandWords.id)
        }
        if data.totalWords >= 10000 {
            data.unlockedAchievements.insert(Achievement.tenThousandWords.id)
        }

        // Check streak achievements
        if data.currentStreak >= 7 {
            data.unlockedAchievements.insert(Achievement.sevenDayStreak.id)
        }
        if data.currentStreak >= 30 {
            data.unlockedAchievements.insert(Achievement.thirtyDayStreak.id)
        }
    }

    // MARK: - Helper Methods

    func countWords(in text: String) -> Int {
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        return words.filter { !$0.isEmpty }.count
    }

    private func dateKey(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withYear, .withMonth, .withDay]
        return formatter.string(from: date)
    }

    private func dateFromKey(_ key: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withYear, .withMonth, .withDay]
        return formatter.date(from: key)
    }

    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }

    // MARK: - Reset

    func resetAllStatistics() {
        data = StatisticsData()
        saveData()
    }
}

// MARK: - Formatting Helpers

extension StatisticsManager {
    var formattedTotalWords: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: data.totalWords)) ?? "\(data.totalWords)"
    }

    var formattedMostProductiveDay: String {
        guard let date = data.mostProductiveDay else {
            return "No data yet"
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return "\(formatter.string(from: date)) (\(data.mostProductiveDayWords) words)"
    }

    var favoriteModel: String {
        guard !data.modelUsage.isEmpty else { return "None" }
        let sorted = data.modelUsage.sorted { $0.value > $1.value }
        return sorted.first?.key ?? "None"
    }
}
