import PadelCore
import SwiftData
import SwiftUI

struct PlayerDetailView: View {
    let player: Player

    @Query(filter: #Predicate<Match> { $0.isComplete }, sort: \Match.startedAt, order: .reverse) private var matches: [Match]
    @Query(sort: \Player.displayName) private var players: [Player]

    var body: some View {
        // Derive once per render instead of from computed properties that each
        // re-walked the full match history (this view also recurses into itself
        // for partners).
        let summaries = matches.map(\.summary)
        let playerByID = Dictionary(players.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let insights = MatchStatistics.playerInsights(
            for: player.id,
            displayName: player.displayName,
            in: summaries
        )
        let partnerSummaries = MatchStatistics.partnerStats(
            for: player.id,
            in: summaries,
            displayNames: playerByID.mapValues(\.displayName)
        )
        let recentMatches = matches
            .filter { $0.roster.contains(playerID: player.id) }
            .prefix(10)
            .map { $0 }

        return List {
            if insights.matchCount == 0 {
                ContentUnavailableView(
                    String(localized: "No matches yet"),
                    systemImage: "person.crop.circle",
                    description: Text(
                        String(localized: "Complete a match with this player to see stats.")
                    )
                )
            } else {
                Section(String(localized: "Record")) {
                    if let winRate = insights.winRate {
                        LabeledContent(String(localized: "Win rate")) {
                            Text(MatchFormatting.percentageText(for: winRate))
                        }
                        .accessibilityLabel(
                            String(
                                localized: "Win rate \(MatchFormatting.percentageText(for: winRate))"
                            )
                        )
                    }
                    LabeledContent(String(localized: "Matches played")) {
                        Text("\(insights.matchCount)")
                    }
                    LabeledContent(String(localized: "Wins")) {
                        Text("\(insights.wins)")
                    }
                    LabeledContent(String(localized: "Losses")) {
                        Text("\(insights.losses)")
                    }
                }

                CourtSideInsightsSection(insights: insights)

                ServeInsightsSection(insights: insights)

                Section(String(localized: "Duration")) {
                    if let averageDuration = insights.averageDuration {
                        LabeledContent(String(localized: "Average duration")) {
                            Text(MatchFormatting.durationText(for: averageDuration))
                        }
                    }
                }

                Section(String(localized: "Golden point")) {
                    LabeledContent(String(localized: "Deciding points played")) {
                        Text("\(insights.goldenPointOpportunities)")
                    }
                    if let conversionRate = insights.goldenPointConversionRate {
                        LabeledContent(String(localized: "Conversion")) {
                            Text(MatchFormatting.percentageText(for: conversionRate))
                        }
                        .accessibilityLabel(
                            String(
                                localized: "Golden point conversion \(MatchFormatting.percentageText(for: conversionRate))"
                            )
                        )
                    } else {
                        Text(
                            String(
                                localized: "Play matches with golden point or star point rules to track conversion."
                            )
                        )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                }

                if !partnerSummaries.isEmpty {
                    Section(String(localized: "Partners")) {
                        ForEach(partnerSummaries) { summary in
                            if let partner = playerByID[summary.id] {
                                NavigationLink {
                                    PlayerDetailView(player: partner)
                                } label: {
                                    PartnerSummaryRowView(summary: summary)
                                }
                            }
                        }
                    }
                }

                if !recentMatches.isEmpty {
                    Section(String(localized: "Recent matches")) {
                        ForEach(recentMatches) { match in
                            NavigationLink {
                                MatchDetailView(match: match)
                            } label: {
                                MatchRowView(match: match, focusPlayerID: player.id)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(player.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PartnerSummaryRowView: View {
    let summary: PartnerSummary

    var body: some View {
        PlayerStatRowView(
            displayName: summary.displayName,
            countText: String(localized: "\(summary.matchCount) matches together"),
            winRate: summary.winRate,
            accessibilityLabel: rowAccessibilityLabel
        )
    }

    private var rowAccessibilityLabel: String {
        if let winRate = summary.winRate {
            return String(
                localized: "\(summary.displayName), \(summary.matchCount) matches together, win rate \(MatchFormatting.percentageText(for: winRate))"
            )
        }
        return String(localized: "\(summary.displayName), \(summary.matchCount) matches together")
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        PlayerDetailView(player: Player(displayName: "Alex"))
    }
    .modelContainer(PreviewData.container)
}
#endif
