import PadelCore
import SwiftUI

struct SettingsView: View {
    @Environment(PhoneSyncCoordinator.self) private var syncCoordinator
    @Environment(CurrentUserStore.self) private var currentUserStore
    @State private var bestOfSets = MatchRulesSettingsForm.bestOfSets(from: .default)
    @State private var gamePointStyle = MatchRules.default.gamePointStyle
    @State private var setTieBreak = MatchRules.default.setTieBreak
    @State private var finalSetTieBreak = MatchRules.default.finalSetTieBreak
    @State private var healthStatus = HealthKitAuthorizationChecker.workoutAuthorizationStatus()
    @State private var preferredMeSlot = MeProfilePreferences.preferredSlot()

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        Form {
            AccountAuthSection()

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

            meSlotSection

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
            syncCoordinator.syncDefaultRulesToWatch()
            preferredMeSlot = MeProfilePreferences.preferredSlot()
        }
        .onChange(of: bestOfSets) { _, _ in saveDefaults() }
        .onChange(of: gamePointStyle) { _, _ in saveDefaults() }
        .onChange(of: setTieBreak) { _, _ in saveDefaults() }
        .onChange(of: finalSetTieBreak) { _, _ in saveDefaults() }
        .onChange(of: preferredMeSlot) { _, newValue in
            MeProfilePreferences.savePreferredSlot(newValue)
            syncCoordinator.syncPhoneContextToWatch()
        }
        .onChange(of: currentUserStore.isSignedIn) { _, _ in
            syncCoordinator.syncPhoneContextToWatch()
        }
    }

    @ViewBuilder
    private var meSlotSection: some View {
        MeSlotSettingsSection(preferredMeSlot: $preferredMeSlot)
    }

    private func loadDefaults() {
        let values = MatchRulesSettingsForm.loadValues(from: MatchRulesPreferences.load())
        bestOfSets = values.bestOfSets
        gamePointStyle = values.gamePointStyle
        setTieBreak = values.setTieBreak
        finalSetTieBreak = values.finalSetTieBreak
    }

    private func saveDefaults() {
        let rules = MatchRulesSettingsForm.makeRules(
            bestOfSets: bestOfSets,
            gamePointStyle: gamePointStyle,
            setTieBreak: setTieBreak,
            finalSetTieBreak: finalSetTieBreak
        )
        MatchRulesPreferences.save(rules)
        syncCoordinator.syncDefaultRulesToWatch()
    }
}

private struct MeSlotSettingsSection: View {
    @Environment(CurrentUserStore.self) private var currentUserStore
    @Binding var preferredMeSlot: PlayerSlot

    var body: some View {
        if currentUserStore.isSignedIn {
            Section(String(localized: "Your match setup")) {
                Picker(String(localized: "Default position"), selection: $preferredMeSlot) {
                    ForEach(PlayerSlot.allCases) { slot in
                        Text(slot.label).tag(slot)
                    }
                }
                .accessibilityLabel(String(localized: "Default position on new match"))
            }
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .environment(PhoneSyncCoordinator(syncListener: PhoneConnectivityListener()))
    .environment(CurrentUserStore())
}
