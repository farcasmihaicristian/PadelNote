import PadelCore
import SwiftUI

struct NewMatchSetupView: View {
    var onFinished: () -> Void = {}

    @State private var bestOfSets = MatchRulesSettingsForm.bestOfSets(from: .default)
    @State private var gamePointStyle = MatchRules.default.gamePointStyle
    @State private var setTieBreak = MatchRules.default.setTieBreak
    @State private var finalSetTieBreak = MatchRules.default.finalSetTieBreak
    @State private var teamAName = ""
    @State private var teamBName = ""
    @State private var startLiveMatch = false

    private var rules: MatchRules {
        MatchRulesSettingsForm.makeRules(
            bestOfSets: bestOfSets,
            gamePointStyle: gamePointStyle,
            setTieBreak: setTieBreak,
            finalSetTieBreak: finalSetTieBreak
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
        .onAppear(perform: loadDefaults)
        .navigationDestination(isPresented: $startLiveMatch) {
            LiveMatchView(
                rules: rules,
                teamAName: teamAName,
                teamBName: teamBName,
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
