import PadelCore
import SwiftUI

struct SettingsView: View {
    @State private var bestOfSets = MatchRulesSettingsForm.bestOfSets(from: .default)
    @State private var gamePointStyle = MatchRules.default.gamePointStyle
    @State private var setTieBreak = MatchRules.default.setTieBreak
    @State private var finalSetTieBreak = MatchRules.default.finalSetTieBreak
    @State private var healthStatus = HealthKitAuthorizationChecker.workoutAuthorizationStatus()

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

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

            Section(String(localized: "Deuce rules explained")) {
                Text(String(localized: "Star point is limited advantage: classic advantage applies for the first two deuces, then the third deuce is a sudden-death golden point."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section(String(localized: "Health")) {
                LabeledContent(String(localized: "HealthKit access")) {
                    Text(HealthKitAuthorizationChecker.statusLabel(for: healthStatus))
                }
                .accessibilityLabel(
                    String(
                        localized: "HealthKit access \(HealthKitAuthorizationChecker.statusLabel(for: healthStatus))"
                    )
                )

                Text(String(localized: "Workouts are recorded on Apple Watch during matches. Manage permissions in the Health app."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section(String(localized: "About")) {
                LabeledContent(String(localized: "App")) {
                    Text("PadelNote")
                }
                LabeledContent(String(localized: "Version")) {
                    Text(appVersion)
                }
                Text(String(localized: "Keep score. Keep history. Keep playing."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(String(localized: "Settings"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadDefaults()
            healthStatus = HealthKitAuthorizationChecker.workoutAuthorizationStatus()
        }
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
