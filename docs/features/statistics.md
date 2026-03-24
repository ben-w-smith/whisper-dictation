# Statistics

Usage tracking, streaks, and achievements in DictationApp.

## Overview

StatisticsManager tracks transcription usage including word counts, session counts, and streaks. Data is persisted in UserDefaults and displayed in the settings UI.

## Tracked Metrics

| Metric | Description |
|--------|-------------|
| `totalWords` | Cumulative word count across all transcriptions |
| `totalSessions` | Number of transcription sessions |
| `currentStreak` | Consecutive days with at least one transcription |
| `longestStreak` | Best streak achieved |
| `wordsToday` | Words transcribed today |
| `wordsThisWeek` | Words transcribed this week |
| `wordsThisMonth` | Words transcribed this month |
| `modelUsage` | Count per model used |
| `mostProductiveDay` | Date with highest word count |

## Data Model

```swift
struct StatisticsData: Codable {
    var totalWords: Int = 0
    var totalSessions: Int = 0
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var wordsToday: Int = 0
    var wordsThisWeek: Int = 0
    var wordsThisMonth: Int = 0
    var modelUsage: [String: Int] = [:]
    var totalRecordingSeconds: Double = 0
    var mostProductiveDay: Date?
    var mostProductiveDayWords: Int = 0
    var unlockedAchievements: Set<String> = []
    var lastActiveDate: Date?
    var dailyWordCounts: [String: Int] = [:]  // "YYYY-MM-DD" -> count
}
```

## Achievements

### Available Achievements

| ID | Title | Description | Threshold |
|----|-------|-------------|-----------|
| `1000_words` | Word Collector | Transcribe 1,000 words | 1,000 words |
| `10000_words` | Prolific Writer | Transcribe 10,000 words | 10,000 words |
| `7_day_streak` | Week Warrior | 7-day transcription streak | 7 days |
| `30_day_streak` | Monthly Master | 30-day transcription streak | 30 days |

### Achievement Definition

```swift
struct Achievement: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let icon: String
    let threshold: Int
}
```

## Streak Calculation

Streaks count consecutive days with transcription activity:

```swift
private func calculateStreak() {
    let today = calendar.startOfDay(for: now)
    let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

    var streak = 0
    var checkDate = today

    // Start from today if activity exists
    if data.dailyWordCounts[todayKey, default: 0] > 0 {
        streak = 1
        checkDate = yesterday
    }

    // Count consecutive days backwards
    while data.dailyWordCounts[dateKey(checkDate), default: 0] > 0 {
        streak += 1
        checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
    }

    data.currentStreak = streak
}
```

## Usage Updates

Statistics are updated in two ways:

### From Transcription History

```swift
func updateFromTranscriptions(_ transcriptions: [Transcription]) {
    resetDailyCounts()
    calculateFromTranscriptions(transcriptions)
    recalculateStats()
    checkAchievements()
}
```

### Per Transcription

```swift
func recordTranscription(_ transcription: Transcription) {
    let wordCount = countWords(in: transcription.text)
    data.totalWords += wordCount
    data.totalSessions += 1
    data.dailyWordCounts[todayKey, default: 0] += wordCount
    // ...
    checkAchievements()
}
```

## Persistence

Data is stored in UserDefaults as JSON:

```swift
private let userDefaultsKey = "dictationStatistics"

private func saveData() {
    guard let encoded = try? JSONEncoder().encode(data) else { return }
    UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
}
```

## Display

The compact summary is shown in the menu bar:

```swift
var compactSummary: String {
    let wordsFormatted = formatNumber(data.totalWords)
    return "\(wordsFormatted) words | \(data.currentStreak) day streak"
}
```

## Cross-References

- [Swift Guide](../swift-guide.md) - StatisticsManager implementation
- [Transcription](transcription.md) - What generates the statistics

---

*Last updated: 2026-03-24*
