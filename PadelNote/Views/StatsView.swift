import PadelCore
import SwiftData
import SwiftUI

struct StatsView: View {
    @Query(sort: \Match.startedAt, order: .reverse) private var matches: [Match]

    private var insights: MatchInsights {
        MatchStatistics.insights(for: matches.map(\.summary))
    }

    var body: some View {
        List {
            if insights.completedMatchCount == 0 {
                ContentUnavailableView(
                    String(localized: "No stats yet"),
                    systemImage: "chart.bar",
                    description: Text(String(localized: "Complete a match to start building insights."))
                )
            } else {
                Section(String(localized: "Overview")) {
                    LabeledContent(String(localized: "Matches played")) {
                        Text("\(insights.completedMatchCount)")
                    }
                    if let winRate = insights.teamAWinRate {
                        LabeledContent(String(localized: "Team A win rate")) {
                            Text(MatchFormatting.percentageText(for: winRate))
                        }
                        .accessibilityLabel(
                            String(
                                localized: "Team A win rate \(MatchFormatting.percentageText(for: winRate))"
                            )
                        )
                    }
                    LabeledContent(String(localized: "Team A wins")) {
                        Text("\(insights.teamAWins)")
                    }
                    LabeledContent(String(localized: "Team B wins")) {
                        Text("\(insights.teamBWins)")
                    }
                }

                Section(String(localized: "Duration")) {
                    if let averageDuration = insights.averageDuration {
                        LabeledContent(String(localized: "Average duration")) {
                            Text(MatchFormatting.durationText(for: averageDuration))
                        }
                    }
                    if let longestDuration = insights.longestDuration {
                        LabeledContent(String(localized: "Longest match")) {
                            Text(MatchFormatting.durationText(for: longestDuration))
                        }
                    }
                }

                Section(String(localized: "Golden point")) {
                    LabeledContent(String(localized: "Deciding points played")) {
                        Text("\(insights.goldenPointOpportunities)")
                    }
                    if let conversionRate = insights.goldenPointConversionRate {
                        LabeledContent(String(localized: "Team A conversion")) {
                            Text(MatchFormatting.percentageText(for: conversionRate))
                        }
                        .accessibilityLabel(
                            String(
                                localized: "Team A golden point conversion \(MatchFormatting.percentageText(for: conversionRate))"
                            )
                        )
                    } else {
                        Text(String(localized: "Play matches with golden point or star point rules to track conversion."))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Text(String(localized: "Win rate and golden point conversion are based on Team A in match setup."))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(String(localized: "Insights"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        StatsView()
    }
    .modelContainer(PreviewData.container)
}
