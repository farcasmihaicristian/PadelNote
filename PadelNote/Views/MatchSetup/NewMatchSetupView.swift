import PadelCore
import SwiftData
import SwiftUI

struct NewMatchSetupView: View {
    var onFinished: () -> Void = {}

    @Environment(CurrentUserStore.self) private var currentUserStore
    @Environment(PhoneSyncCoordinator.self) private var syncCoordinator
    @Environment(\.modelContext) private var modelContext
    @State private var bestOfSets = MatchRulesSettingsForm.bestOfSets(from: .default)
    @State private var gamePointStyle = MatchRules.default.gamePointStyle
    @State private var setTieBreak = MatchRules.default.setTieBreak
    @State private var finalSetTieBreak = MatchRules.default.finalSetTieBreak
    @State private var playerSetup = MatchPlayerSetup.empty
    @State private var firstServer: PlayerSlot = MeProfilePreferences.preferredSlot()
    // Loaded once from history in `onAppear` rather than re-fetched from the
    // database on every render / keystroke in the name fields.
    @State private var knownPlayerNames: [String] = []
    @State private var linkedHistoryPlayers: [Player] = []

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

            Section(String(localized: "Bottom side")) {
                PlayerNameField(
                    selection: $playerSetup.sideAPlayer1,
                    label: String(localized: "Right"),
                    knownNames: knownPlayerNames,
                    linkedPlayers: linkedHistoryPlayers
                )
                PlayerNameField(
                    selection: $playerSetup.sideAPlayer2,
                    label: String(localized: "Left"),
                    knownNames: knownPlayerNames,
                    linkedPlayers: linkedHistoryPlayers
                )
            }

            Section(String(localized: "Top side")) {
                PlayerNameField(
                    selection: $playerSetup.sideBPlayer1,
                    label: String(localized: "Right"),
                    knownNames: knownPlayerNames,
                    linkedPlayers: linkedHistoryPlayers
                )
                PlayerNameField(
                    selection: $playerSetup.sideBPlayer2,
                    label: String(localized: "Left"),
                    knownNames: knownPlayerNames,
                    linkedPlayers: linkedHistoryPlayers
                )
            }

            Section(String(localized: "Serve")) {
                Picker(String(localized: "First serve"), selection: $firstServer) {
                    ForEach(PlayerSlot.allCases) { slot in
                        Text(serverLabel(for: slot)).tag(slot)
                    }
                }
                .accessibilityLabel(String(localized: "First server"))
            }

            Section {
                Button {
                    saveRulesForWatch()
                    onFinished()
                } label: {
                    Text(String(localized: "Save for Apple Watch"))
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .accessibilityLabel(String(localized: "Save for Apple Watch"))
                .accessibilityHint(String(localized: "Save match settings and score on your Apple Watch"))
            }
        }
        .navigationTitle(String(localized: "New match"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            PlayerPersistence.pruneUnreferencedPlayers(context: modelContext)
            reloadPlayerLists()
            loadDefaults()
            applyMeProfileIfNeeded()
        }
        .onChange(of: currentUserStore.mePlayer?.id) { _, _ in
            applyMeProfileIfNeeded()
        }
    }

    private func saveRulesForWatch() {
        MatchRulesPreferences.save(rules)
        syncCoordinator.syncDefaultRulesToWatch()
    }

    private func reloadPlayerLists() {
        knownPlayerNames = PlayerPersistence.knownNamesFromMatchHistory(context: modelContext)
        linkedHistoryPlayers = PlayerPersistence.playersFromMatchHistory(context: modelContext)
    }

    private func serverLabel(for slot: PlayerSlot) -> String {
        let name = slot.selection(from: playerSetup).trimmedName
        return name.isEmpty ? slot.label : name
    }

    private func loadDefaults() {
        let values = MatchRulesSettingsForm.loadValues(from: MatchRulesPreferences.load())
        bestOfSets = values.bestOfSets
        gamePointStyle = values.gamePointStyle
        setTieBreak = values.setTieBreak
        finalSetTieBreak = values.finalSetTieBreak
    }

    private func applyMeProfileIfNeeded() {
        guard let mePlayer = currentUserStore.mePlayer else { return }

        let preferredSlot = MeProfilePreferences.preferredSlot()
        guard !preferredSlot.selection(from: playerSetup).hasContent else { return }

        UserAccountPersistence.applyMeProfile(
            to: &playerSetup,
            player: mePlayer,
            preferredSlot: preferredSlot
        )
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        NewMatchSetupView()
    }
    .modelContainer(PreviewData.container)
    .environment(CurrentUserStore())
    .environment(PhoneSyncCoordinator(syncListener: PhoneConnectivityListener()))
}
#endif
