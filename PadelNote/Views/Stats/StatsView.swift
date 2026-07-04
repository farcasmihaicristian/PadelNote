import PadelCore
import SwiftData
import SwiftUI

struct StatsView: View {
    @Environment(CurrentUserStore.self) private var currentUserStore
    @Query(filter: #Predicate<Match> { $0.isComplete }, sort: \Match.startedAt, order: .reverse) private var matches: [Match]
    @Query(sort: \Player.displayName) private var players: [Player]

    var body: some View {
        // Derive everything once per render rather than from several computed
        // properties that each re-walked the full match history.
        let summaries = matches.map(\.summary)
        let overview = MatchStatistics.insights(for: summaries)
        let playerByID = Dictionary(players.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let nameLookup = playerByID.mapValues(\.displayName)
        let playerSummaries = MatchStatistics.playerSummaries(for: summaries, displayNames: nameLookup)
        let meInsights: PlayerInsights? = currentUserStore.mePlayer.map { mePlayer in
            MatchStatistics.playerInsights(
                for: mePlayer.id,
                displayName: mePlayer.displayName,
                in: summaries
            )
        }

        return List {
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
                            if let player = playerByID[summary.id] {
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
        PlayerStatRowView(
            displayName: summary.displayName,
            countText: String(localized: "\(summary.matchCount) matches"),
            winRate: summary.winRate,
            accessibilityLabel: rowAccessibilityLabel
        )
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

#if DEBUG
#Preview {
    NavigationStack {
        StatsView()
    }
    .modelContainer(PreviewData.container)
    .environment(CurrentUserStore())
}
#endif
