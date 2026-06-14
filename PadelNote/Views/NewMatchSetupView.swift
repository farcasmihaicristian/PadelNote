import PadelCore
import SwiftData
import SwiftUI

struct NewMatchSetupView: View {
    var onFinished: () -> Void = {}

    @Environment(CurrentUserStore.self) private var currentUserStore
    @Query(sort: \Player.displayName) private var players: [Player]
    @State private var bestOfSets = MatchRulesSettingsForm.bestOfSets(from: .default)
    @State private var gamePointStyle = MatchRules.default.gamePointStyle
    @State private var setTieBreak = MatchRules.default.setTieBreak
    @State private var finalSetTieBreak = MatchRules.default.finalSetTieBreak
    @State private var playerSetup = MatchPlayerSetup.empty
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

            Section(String(localized: "Players (optional)")) {
                PlayerNameField(
                    selection: $playerSetup.sideAPlayer1,
                    label: String(localized: "Side A player 1"),
                    players: players
                )
                PlayerNameField(
                    selection: $playerSetup.sideAPlayer2,
                    label: String(localized: "Side A player 2"),
                    players: players
                )
            }

            Section {
                PlayerNameField(
                    selection: $playerSetup.sideBPlayer1,
                    label: String(localized: "Side B player 1"),
                    players: players
                )
                PlayerNameField(
                    selection: $playerSetup.sideBPlayer2,
                    label: String(localized: "Side B player 2"),
                    players: players
                )
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

    private func applyMeProfileIfNeeded() {
        guard let mePlayer = currentUserStore.mePlayer else { return }
        UserAccountPersistence.applyMeProfile(to: &playerSetup, player: mePlayer)
    }
}

#Preview {
    NavigationStack {
        NewMatchSetupView()
    }
    .modelContainer(PreviewData.container)
    .environment(CurrentUserStore())
}
