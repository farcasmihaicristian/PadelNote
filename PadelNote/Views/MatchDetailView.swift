import PadelCore
import SwiftUI

struct MatchDetailView: View {
    let match: Match

    var body: some View {
        List {
            Section(String(localized: "Final score")) {
                Text(match.scoreSummary)
                    .font(.title2.bold())
                    .accessibilityLabel(String(localized: "Final score \(match.scoreSummary)"))

                LabeledContent(String(localized: "Winner")) {
                    Text(MatchFormatting.winnerLabel(for: match))
                }
            }

            Section(String(localized: "Sets")) {
                if match.completedSets.isEmpty {
                    Text(String(localized: "No completed sets"))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(match.completedSets.enumerated()), id: \.offset) { index, set in
                        LabeledContent(String(localized: "Set \(index + 1)")) {
                            Text(ScoreFormatter.formatSetScore(set))
                        }
                    }
                }
            }

            Section(String(localized: "Match info")) {
                LabeledContent(String(localized: "Started")) {
                    Text(MatchFormatting.dayTitle(for: match.startedAt))
                }

                if let duration = match.duration {
                    LabeledContent(String(localized: "Duration")) {
                        Text(MatchFormatting.durationText(for: duration))
                    }
                }

                LabeledContent(String(localized: "Rule style")) {
                    Text(ruleStyleLabel)
                }
            }
        }
        .navigationTitle(String(localized: "Match detail"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var ruleStyleLabel: String {
        switch match.rules.gamePointStyle {
        case .advantage:
            String(localized: "Advantage")
        case .goldenPoint:
            String(localized: "Golden point")
        case .starPoint:
            String(localized: "Star point")
        }
    }
}

#Preview {
    NavigationStack {
        MatchDetailView(match: Match(
            startedAt: .now.addingTimeInterval(-3600),
            endedAt: .now,
            rules: .default,
            completedSets: [SetScore(gamesA: 6, gamesB: 4), SetScore(gamesA: 7, gamesB: 6, tieBreakA: 7, tieBreakB: 5)],
            winner: .a,
            teamAName: "Alex & Maria",
            teamBName: "Chris & Dana"
        ))
    }
}
