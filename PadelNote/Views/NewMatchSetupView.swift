import PadelCore
import SwiftData
import SwiftUI

struct NewMatchSetupView: View {
    var onFinished: () -> Void = {}

    @Environment(CurrentUserStore.self) private var currentUserStore
    @Environment(\.modelContext) private var modelContext
    @State private var bestOfSets = MatchRulesSettingsForm.bestOfSets(from: .default)
    @State private var gamePointStyle = MatchRules.default.gamePointStyle
    @State private var setTieBreak = MatchRules.default.setTieBreak
    @State private var finalSetTieBreak = MatchRules.default.finalSetTieBreak
    @State private var playerSetup = MatchPlayerSetup.empty
    @State private var firstServer: PlayerSlot = MeProfilePreferences.preferredSlot()
    @State private var startLiveMatch = false

    private var rules: MatchRules {
        MatchRulesSettingsForm.makeRules(
            bestOfSets: bestOfSets,
            gamePointStyle: gamePointStyle,
            setTieBreak: setTieBreak,
            finalSetTieBreak: finalSetTieBreak
        )
    }

    private var knownPlayerNames: [String] {
        PlayerPersistence.knownNamesFromMatchHistory(context: modelContext)
    }

    private var linkedHistoryPlayers: [Player] {
        PlayerPersistence.playersFromMatchHistory(context: modelContext)
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
        .onAppear {
            PlayerPersistence.pruneUnreferencedPlayers(context: modelContext)
            loadDefaults()
            applyMeProfileIfNeeded()
        }
        .onChange(of: currentUserStore.mePlayer?.id) { _, _ in
            applyMeProfileIfNeeded()
        }
        .navigationDestination(isPresented: $startLiveMatch) {
            LiveMatchView(
                rules: rules,
                playerSetup: playerSetup,
                firstServer: firstServer,
                onFinished: onFinished
            )
        }
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

#Preview {
    NavigationStack {
        NewMatchSetupView()
    }
    .modelContainer(PreviewData.container)
    .environment(CurrentUserStore())
}
