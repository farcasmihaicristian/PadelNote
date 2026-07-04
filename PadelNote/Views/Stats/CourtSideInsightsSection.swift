import PadelCore
import SwiftUI

struct CourtSideInsightsSection: View {
    let insights: PlayerInsights

    private var hasCourtSideData: Bool {
        insights.leftSideStats.matchCount > 0 || insights.rightSideStats.matchCount > 0
    }

    var body: some View {
        if hasCourtSideData {
            Section(String(localized: "Court position")) {
                Text(String(localized: "Win rate when playing left vs right on court."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                roleRow(
                    title: String(localized: "Left side"),
                    stats: insights.leftSideStats
                )
                roleRow(
                    title: String(localized: "Right side"),
                    stats: insights.rightSideStats
                )
            }
        }
    }

    private func roleRow(title: String, stats: RolePerformanceStats) -> some View {
        LabeledContent(title) {
            Text(MatchFormatting.rolePerformanceText(for: stats))
                .foregroundStyle(stats.matchCount == 0 ? .secondary : .primary)
        }
        .accessibilityLabel(
            String(localized: "\(title), \(MatchFormatting.rolePerformanceText(for: stats))")
        )
    }
}
