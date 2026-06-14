import PadelCore
import SwiftData
import SwiftUI

struct PlayerDetailView: View {
    let player: Player

    @Query(sort: \Match.startedAt, order: .reverse) private var matches: [Match]

    private var summaries: [MatchSummary] {
        matches.map(\.summary)
    }

    private var insights: PlayerInsights {
        MatchStatistics.playerInsights(
            for: player.id,
            displayName: player.displayName,
            in: summaries
        )
    }

    private var recentMatches: [Match] {
        matches.filter { match in
            match.isCompleted && match.roster.contains(playerID: player.id)
        }
        .prefix(10)
        .map { $0 }
    }

    var body: some View {
        List {
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

                if !recentMatches.isEmpty {
                    Section(String(localized: "Recent matches")) {
                        ForEach(recentMatches) { match in
                            NavigationLink {
                                MatchDetailView(match: match)
                            } label: {
                                MatchRowView(match: match)
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

#Preview {
    NavigationStack {
        PlayerDetailView(player: Player(displayName: "Alex"))
    }
    .modelContainer(PreviewData.container)
}
