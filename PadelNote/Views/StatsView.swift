import PadelCore
import SwiftData
import SwiftUI

struct StatsView: View {
    @Environment(CurrentUserStore.self) private var currentUserStore
    @Query(sort: \Match.startedAt, order: .reverse) private var matches: [Match]
    @Query(sort: \Player.displayName) private var players: [Player]

    private var summaries: [MatchSummary] {
        matches.map(\.summary)
    }

    private var overview: MatchInsights {
        MatchStatistics.insights(for: summaries)
    }

    private var playerNameLookup: [UUID: String] {
        Dictionary(uniqueKeysWithValues: players.map { ($0.id, $0.displayName) })
    }

    private var playerSummaries: [PlayerSummary] {
        MatchStatistics.playerSummaries(for: summaries, displayNames: playerNameLookup)
    }

    private var meInsights: PlayerInsights? {
        guard let mePlayer = currentUserStore.mePlayer else { return nil }
        return MatchStatistics.playerInsights(
            for: mePlayer.id,
            displayName: mePlayer.displayName,
            in: summaries
        )
    }

    var body: some View {
        List {
            if overview.completedMatchCount == 0 {
                ContentUnavailableView(
                    String(localized: "No stats yet"),
                    systemImage: "chart.bar",
                    description: Text(String(localized: "Complete a match to start building insights."))
                )
            } else {
                if let mePlayer = currentUserStore.mePlayer, let meInsights {
                    YouInsightsSection(player: mePlayer, insights: meInsights)
                }

                Section(String(localized: "Overview")) {
                    LabeledContent(String(localized: "Matches played")) {
                        Text("\(overview.completedMatchCount)")
                    }
                }

                Section(String(localized: "Duration")) {
                    if let averageDuration = overview.averageDuration {
                        LabeledContent(String(localized: "Average duration")) {
                            Text(MatchFormatting.durationText(for: averageDuration))
                        }
                    }
                    if let longestDuration = overview.longestDuration {
                        LabeledContent(String(localized: "Longest match")) {
                            Text(MatchFormatting.durationText(for: longestDuration))
                        }
                    }
                }

                Section(String(localized: "Golden point")) {
                    LabeledContent(String(localized: "Deciding points played")) {
                        Text("\(overview.goldenPointOpportunities)")
                    }
                    Text(String(localized: "Per-player conversion is shown on each player profile."))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section(String(localized: "Players")) {
                    if playerSummaries.isEmpty {
                        Text(String(localized: "Name players when starting a match to track individual stats."))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(playerSummaries) { summary in
                            if let player = players.first(where: { $0.id == summary.id }) {
                                NavigationLink {
                                    PlayerDetailView(player: player)
                                } label: {
                                    PlayerSummaryRowView(summary: summary)
                                }
                            }
                        }
                    }
                }

                if !currentUserStore.isSignedIn {
                    Section {
                        Text(String(localized: "Set up your profile to track personal stats"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        NavigationLink {
                            SettingsView()
                        } label: {
                            Text(String(localized: "Open Settings to set up profile"))
                        }
                        .accessibilityLabel(String(localized: "Open Settings to set up profile"))
                    }
                }
            }
        }
        .navigationTitle(String(localized: "Insights"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PlayerSummaryRowView: View {
    let summary: PlayerSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(summary.displayName)
                .font(.headline)

            HStack(spacing: 12) {
                Text(String(localized: "\(summary.matchCount) matches"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let winRate = summary.winRate {
                    Text(MatchFormatting.percentageText(for: winRate))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(rowAccessibilityLabel)
    }

    private var rowAccessibilityLabel: String {
        if let winRate = summary.winRate {
            return String(
                localized: "\(summary.displayName), \(summary.matchCount) matches, win rate \(MatchFormatting.percentageText(for: winRate))"
            )
        }
        return String(localized: "\(summary.displayName), \(summary.matchCount) matches")
    }
}

#Preview {
    NavigationStack {
        StatsView()
    }
    .modelContainer(PreviewData.container)
    .environment(CurrentUserStore())
}
