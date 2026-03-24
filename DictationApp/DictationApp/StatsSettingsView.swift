import SwiftUI

struct StatsSettingsView: View {
    @StateObject private var statsManager = StatisticsManager.shared

    var body: some View {
        Form {
            Section {
                // Streak display
                HStack(spacing: 24) {
                    VStack(spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .foregroundStyle(.orange)
                            Text("\(statsManager.data.currentStreak)")
                                .font(.title)
                                .fontWeight(.bold)
                        }
                        Text("Current Streak")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.circle.fill")
                                .foregroundStyle(.red)
                            Text("\(statsManager.data.longestStreak)")
                                .font(.title)
                                .fontWeight(.bold)
                        }
                        Text("Longest Streak")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.vertical, 8)
            } header: {
                Text("Streaks")
            }

            Section {
                HStack {
                    StatItemView(value: statsManager.formattedTotalWords, label: "Total")
                    StatItemView(value: "\(statsManager.data.wordsToday)", label: "Today")
                    StatItemView(value: "\(statsManager.data.wordsThisWeek)", label: "This Week")
                    StatItemView(value: "\(statsManager.data.wordsThisMonth)", label: "This Month")
                }
            } header: {
                Text("Words Transcribed")
            }

            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(statsManager.data.totalSessions)")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("Total Sessions")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: "%.0f", statsManager.averageWpm))
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("Avg WPM (estimated)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundStyle(.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Most Productive Day")
                            .font(.subheadline)
                        Text(statsManager.formattedMostProductiveDay)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            } header: {
                Text("Sessions")
            }

            if !statsManager.data.modelUsage.isEmpty {
                Section {
                    ForEach(statsManager.data.modelUsage.sorted(by: { $0.value > $1.value }), id: \.key) { model, count in
                        HStack {
                            Text(model)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(count) sessions")
                                .fontWeight(.medium)
                        }
                    }
                } header: {
                    Text("Model Usage")
                }
            }

            Section {
                if statsManager.unlockedAchievementsList.isEmpty {
                    Text("Keep dictating to unlock achievements!")
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                } else {
                    ForEach(statsManager.unlockedAchievementsList) { achievement in
                        HStack(spacing: 12) {
                            Image(systemName: achievement.icon)
                                .foregroundStyle(.yellow)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(achievement.title)
                                    .fontWeight(.medium)
                                Text(achievement.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                }

                // Progress toward next achievement
                if let nextAchievement = statsManager.lockedAchievements.first {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: nextAchievement.icon)
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(nextAchievement.title)
                                    .fontWeight(.medium)
                                Text(nextAchievement.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        let progress = progressToward(achievement: nextAchievement)
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.secondary.opacity(0.2))
                                    .frame(height: 6)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.accentColor)
                                    .frame(width: geometry.size.width * CGFloat(progress), height: 6)
                            }
                        }
                        .frame(height: 6)

                        Text(progressDescription(for: nextAchievement))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("Achievements")
            } footer: {
                Text("\(statsManager.unlockedAchievementsList.count) of \(Achievement.allAchievements.count) unlocked")
            }

            Section {
                Button(role: .destructive) {
                    statsManager.resetAllStatistics()
                } label: {
                    Text("Reset All Statistics")
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .formStyle(.grouped)
    }

    private func progressToward(achievement: Achievement) -> Double {
        switch achievement.id {
        case "1000_words":
            return min(1.0, Double(statsManager.data.totalWords) / 1000.0)
        case "10000_words":
            return min(1.0, Double(statsManager.data.totalWords) / 10000.0)
        case "7_day_streak":
            return min(1.0, Double(statsManager.data.currentStreak) / 7.0)
        case "30_day_streak":
            return min(1.0, Double(statsManager.data.currentStreak) / 30.0)
        default:
            return 0
        }
    }

    private func progressDescription(for achievement: Achievement) -> String {
        switch achievement.id {
        case "1000_words":
            return "\(statsManager.data.totalWords) / 1,000 words"
        case "10000_words":
            return "\(statsManager.data.totalWords) / 10,000 words"
        case "7_day_streak":
            return "\(statsManager.data.currentStreak) / 7 days"
        case "30_day_streak":
            return "\(statsManager.data.currentStreak) / 30 days"
        default:
            return ""
        }
    }
}

struct StatItemView: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    StatsSettingsView()
        .frame(width: 550, height: 580)
}
