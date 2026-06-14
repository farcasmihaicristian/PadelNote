import PadelCore
import SwiftUI

struct SettingsView: View {
    @State private var bestOfSets = MatchRulesSettingsForm.bestOfSets(from: .default)
    @State private var gamePointStyle = MatchRules.default.gamePointStyle
    @State private var setTieBreak = MatchRules.default.setTieBreak
    @State private var finalSetTieBreak = MatchRules.default.finalSetTieBreak

    var body: some View {
        Form {
            Section {
                Text(String(localized: "These options are used as defaults when you start a new match."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            MatchRulesSettingsForm(
                bestOfSets: $bestOfSets,
                gamePointStyle: $gamePointStyle,
                setTieBreak: $setTieBreak,
                finalSetTieBreak: $finalSetTieBreak
            )
        }
        .navigationTitle(String(localized: "Settings"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: loadDefaults)
        .onChange(of: bestOfSets) { _, _ in saveDefaults() }
        .onChange(of: gamePointStyle) { _, _ in saveDefaults() }
        .onChange(of: setTieBreak) { _, _ in saveDefaults() }
        .onChange(of: finalSetTieBreak) { _, _ in saveDefaults() }
    }

    private func loadDefaults() {
        let values = MatchRulesSettingsForm.loadValues(from: MatchRulesPreferences.load())
        bestOfSets = values.bestOfSets
        gamePointStyle = values.gamePointStyle
        setTieBreak = values.setTieBreak
        finalSetTieBreak = values.finalSetTieBreak
    }

    private func saveDefaults() {
        MatchRulesPreferences.save(
            MatchRulesSettingsForm.makeRules(
                bestOfSets: bestOfSets,
                gamePointStyle: gamePointStyle,
                setTieBreak: setTieBreak,
                finalSetTieBreak: finalSetTieBreak
            )
        )
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
