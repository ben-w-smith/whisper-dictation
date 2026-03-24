import SwiftUI

// MARK: - Compact Stats Row (for ContentView)

struct CompactStatsRow: View {
    @ObservedObject private var statsManager = StatisticsManager.shared

    var body: some View {
        HStack(spacing: 12) {
            // Words count
            Label {
                Text(statsManager.formattedTotalWords)
                    .fontWeight(.medium)
            } icon: {
                Image(systemName: "text.bubble")
                    .font(.caption)
            }
            .font(.caption)

            Text("|")
                .foregroundStyle(.tertiary)

            // Streak
            Label {
                Text("\(statsManager.data.currentStreak) day streak")
                    .fontWeight(.medium)
            } icon: {
                Image(systemName: "flame")
                    .font(.caption)
            }
            .font(.caption)
            .foregroundStyle(statsManager.data.currentStreak > 0 ? .orange : .secondary)

            Spacer()

            // Sessions today indicator
            if statsManager.data.wordsToday > 0 {
                Text("\(statsManager.data.wordsToday) today")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.accentColor.opacity(0.05))
    }
}
