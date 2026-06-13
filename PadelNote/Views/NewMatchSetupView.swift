import PadelCore
import SwiftUI

struct NewMatchSetupView: View {
    var onFinished: () -> Void = {}

    @State private var bestOfSets = 3
    @State private var gamePointStyle = GamePointStyle.goldenPoint
    @State private var setTieBreak = TieBreakStyle.classic
    @State private var finalSetTieBreak = TieBreakStyle.superTieBreak10
    @State private var teamAName = ""
    @State private var teamBName = ""
    @State private var startLiveMatch = false

    private var rules: MatchRules {
        MatchRules(
            setsToWin: setsToWin,
            gamePointStyle: gamePointStyle,
            setTieBreak: setTieBreak,
            finalSetTieBreak: finalSetTieBreak
        )
    }

    private var setsToWin: Int {
        switch bestOfSets {
        case 1: 1
        case 3: 2
        default: 3
        }
    }

    var body: some View {
        Form {
            Section(String(localized: "Match format")) {
                Picker(String(localized: "Sets"), selection: $bestOfSets) {
                    Text(String(localized: "Best of 1")).tag(1)
                    Text(String(localized: "Best of 3")).tag(3)
                    Text(String(localized: "Best of 5")).tag(5)
                }
                .accessibilityLabel(String(localized: "Number of sets"))

                Picker(String(localized: "Deuce rule"), selection: $gamePointStyle) {
                    Text(String(localized: "Golden point")).tag(GamePointStyle.goldenPoint)
                    Text(String(localized: "Advantage")).tag(GamePointStyle.advantage)
                    Text(String(localized: "Star point")).tag(GamePointStyle.starPoint)
                }
                .accessibilityLabel(String(localized: "Deuce rule"))
            }

            if let explanation = ruleExplanation {
                Section(String(localized: "How this rule works")) {
                    Text(explanation)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Section(String(localized: "Tie-break")) {
                Picker(String(localized: "At 6–6"), selection: $setTieBreak) {
                    Text(String(localized: "Classic (to 7)")).tag(TieBreakStyle.classic)
                    Text(String(localized: "Play out games")).tag(TieBreakStyle.none)
                }

                Picker(String(localized: "Deciding set"), selection: $finalSetTieBreak) {
                    Text(String(localized: "Super tie-break (to 10)")).tag(TieBreakStyle.superTieBreak10)
                    Text(String(localized: "Classic (to 7)")).tag(TieBreakStyle.classic)
                    Text(String(localized: "Play out games")).tag(TieBreakStyle.none)
                }
            }

            Section(String(localized: "Teams (optional)")) {
                TextField(String(localized: "Team A name"), text: $teamAName)
                    .accessibilityLabel(String(localized: "Team A name"))
                TextField(String(localized: "Team B name"), text: $teamBName)
                    .accessibilityLabel(String(localized: "Team B name"))
            }

            Section {
                Button {
                    startLiveMatch = true
                } label: {
                    Text(String(localized: "Start scoring"))
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .accessibilityLabel(String(localized: "Start scoring"))
            }
        }
        .navigationTitle(String(localized: "New match"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $startLiveMatch) {
            LiveMatchView(
                rules: rules,
                teamAName: teamAName,
                teamBName: teamBName,
                onFinished: onFinished
            )
        }
    }

    private var ruleExplanation: String? {
        switch gamePointStyle {
        case .goldenPoint:
            String(localized: "At 40-40, the next point wins the game — no advantage games.")
        case .advantage:
            String(localized: "Classic tennis rules: after deuce, a team must win two points in a row.")
        case .starPoint:
            String(localized: "Advantage rules apply for the first two deuces; the third deuce is sudden death.")
        }
    }
}

#Preview {
    NavigationStack {
        NewMatchSetupView()
    }
}
