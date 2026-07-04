import PadelCore
import SwiftData
import SwiftUI

struct YouInsightsSection: View {
    let player: Player
    let insights: PlayerInsights

    var body: some View {
        Section(String(localized: "You")) {
            NavigationLink {
                PlayerDetailView(player: player)
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    Text(player.displayName)
                        .font(.headline)

                    HStack(spacing: 16) {
                        if let winRate = insights.winRate {
                            Text(String(localized: "Win rate \(MatchFormatting.percentageText(for: winRate))"))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Text(String(localized: "\(insights.matchCount) matches"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if let courtSideSummary = courtSideSummary {
                        Text(courtSideSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text(String(localized: "View full profile"))
                        .font(.subheadline)
                }
            }
            .accessibilityLabel(youAccessibilityLabel)
        }
    }

    private var youAccessibilityLabel: String {
        if let winRate = insights.winRate {
            return String(
                localized: "Your profile, win rate \(MatchFormatting.percentageText(for: winRate)), \(insights.matchCount) matches"
            )
        }
        return String(localized: "Your profile, \(insights.matchCount) matches")
    }

    private var courtSideSummary: String? {
        let roles: [(String, RolePerformanceStats)] = [
            (String(localized: "Left side"), insights.leftSideStats),
            (String(localized: "Right side"), insights.rightSideStats),
        ]

        let ranked = roles
            .filter { $0.1.matchCount > 0 && $0.1.winRate != nil }
            .sorted { ($0.1.winRate ?? 0) > ($1.1.winRate ?? 0) }

        guard let best = ranked.first, let winRate = best.1.winRate else { return nil }
        return String(
            localized: "Best on \(best.0): \(MatchFormatting.percentageText(for: winRate)) wins"
        )
    }
}
