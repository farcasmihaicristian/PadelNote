import PadelCore
import SwiftData
import SwiftUI

struct MatchDetailView: View {
    @Bindable var match: Match

    var body: some View {
        let score = MatchScoreText.rendered(for: match)
        let partialSet = match.inProgressSetSummary
        // Replay the engine once for the whole timeline rather than re-replaying a
        // growing prefix for every point.
        let scoreLines = match.scoreLinesBySequence()
        return List {
            Section(String(localized: "Final score")) {
                score.text
                    .font(.title2.bold())
                    .accessibilityLabel(String(localized: "Final score \(score.accessibilityLabel)"))

                LabeledContent(String(localized: "Winner")) {
                    Text(MatchFormatting.winnerLabel(for: match))
                }
            }

            MatchPlayersEditSection(match: match)

            Section(String(localized: "Sets")) {
                if match.completedSets.isEmpty && partialSet == nil {
                    Text(String(localized: "No completed sets"))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(match.completedSets.enumerated()), id: \.offset) { index, set in
                        LabeledContent(String(localized: "Set \(index + 1)")) {
                            Text(ScoreFormatter.formatSetScore(set))
                        }
                    }

                    if let partialSet {
                        LabeledContent(String(localized: "Unfinished set")) {
                            Text(partialSet)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }

            Section(String(localized: "Point timeline")) {
                if match.sortedPoints.isEmpty {
                    Text(String(localized: "No points recorded"))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(match.sortedPoints, id: \.persistentModelID) { point in
                        let line = scoreLines[point.sequence] ?? ""
                        VStack(alignment: .leading, spacing: 4) {
                            Text(
                                String(
                                    localized: "Point \(point.sequence + 1) · \(match.teamName(for: point.team))"
                                )
                            )
                            .font(.headline)

                            Text(line)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(
                            String(
                                localized: "Point \(point.sequence + 1), \(match.teamName(for: point.team)), score \(line)"
                            )
                        )
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

            MatchReflectionSection(match: match)

            if hasHealthData {
                Section(String(localized: "Workout")) {
                    if let heartRate = match.averageHeartRate {
                        LabeledContent(String(localized: "Average heart rate")) {
                            Text(MatchFormatting.heartRateText(for: heartRate))
                        }
                    }
                    if let energy = match.activeEnergyKilocalories {
                        LabeledContent(String(localized: "Active energy")) {
                            Text(MatchFormatting.energyText(for: energy))
                        }
                    }
                    if let distance = match.distanceMeters {
                        LabeledContent(String(localized: "Distance")) {
                            Text(MatchFormatting.distanceText(for: distance))
                        }
                    }
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

    private var hasHealthData: Bool {
        match.averageHeartRate != nil
            || match.activeEnergyKilocalories != nil
            || match.distanceMeters != nil
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
            playerNames: MatchPlayerNames(
                playerA1: "Alex",
                playerA2: "Maria",
                playerB1: "Chris",
                playerB2: "Dana"
            )
        ))
    }
    .modelContainer(PreviewData.container)
}
