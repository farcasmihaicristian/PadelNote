import PadelCore
import SwiftUI

struct NewMatchSetupView: View {
    var onFinished: () -> Void = {}

    @State private var bestOfSets = MatchRulesSettingsForm.bestOfSets(from: .default)
    @State private var gamePointStyle = MatchRules.default.gamePointStyle
    @State private var setTieBreak = MatchRules.default.setTieBreak
    @State private var finalSetTieBreak = MatchRules.default.finalSetTieBreak
    @State private var playerA1Name = ""
    @State private var playerA2Name = ""
    @State private var playerB1Name = ""
    @State private var playerB2Name = ""
    @State private var startLiveMatch = false

    private var rules: MatchRules {
        MatchRulesSettingsForm.makeRules(
            bestOfSets: bestOfSets,
            gamePointStyle: gamePointStyle,
            setTieBreak: setTieBreak,
            finalSetTieBreak: finalSetTieBreak
        )
    }

    private var playerNames: MatchPlayerNames {
        MatchPlayerNames(
            playerA1: playerA1Name,
            playerA2: playerA2Name,
            playerB1: playerB1Name,
            playerB2: playerB2Name
        )
    }

    var body: some View {
        Form {
            MatchRulesSettingsForm(
                bestOfSets: $bestOfSets,
                gamePointStyle: $gamePointStyle,
                setTieBreak: $setTieBreak,
                finalSetTieBreak: $finalSetTieBreak
            )

            Section(String(localized: "Players (optional)")) {
                TextField(String(localized: "Side A player 1"), text: $playerA1Name)
                    .accessibilityLabel(String(localized: "Side A player 1"))
                TextField(String(localized: "Side A player 2"), text: $playerA2Name)
                    .accessibilityLabel(String(localized: "Side A player 2"))
            }

            Section {
                TextField(String(localized: "Side B player 1"), text: $playerB1Name)
                    .accessibilityLabel(String(localized: "Side B player 1"))
                TextField(String(localized: "Side B player 2"), text: $playerB2Name)
                    .accessibilityLabel(String(localized: "Side B player 2"))
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
        .onAppear(perform: loadDefaults)
        .navigationDestination(isPresented: $startLiveMatch) {
            LiveMatchView(
                rules: rules,
                playerNames: playerNames,
                onFinished: onFinished
            )
        }
    }

    private func loadDefaults() {
        let values = MatchRulesSettingsForm.loadValues(from: MatchRulesPreferences.load())
        bestOfSets = values.bestOfSets
        gamePointStyle = values.gamePointStyle
        setTieBreak = values.setTieBreak
        finalSetTieBreak = values.finalSetTieBreak
    }
}

#Preview {
    NavigationStack {
        NewMatchSetupView()
    }
}
