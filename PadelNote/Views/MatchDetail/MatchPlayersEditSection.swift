import PadelCore
import SwiftData
import SwiftUI

struct MatchPlayersEditSection: View {
    @Bindable var match: Match
    @Environment(\.modelContext) private var modelContext
    @Environment(PhoneSyncCoordinator.self) private var syncCoordinator
    @Environment(\.scenePhase) private var scenePhase

    @State private var sideAPlayer1 = ""
    @State private var sideAPlayer2 = ""
    @State private var sideBPlayer1 = ""
    @State private var sideBPlayer2 = ""

    var body: some View {
        Section {
            Text(String(localized: "Edit player names to fix guests or update labels from Watch matches."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }

        Section(String(localized: "Top side")) {
            HStack(alignment: .top, spacing: 16) {
                playerField(
                    title: String(localized: "Left side"),
                    subtitle: String(localized: "Left side"),
                    text: $sideBPlayer2
                )
                playerField(
                    title: String(localized: "Right side"),
                    subtitle: String(localized: "Right side"),
                    text: $sideBPlayer1
                )
            }
        }

        Section(String(localized: "Bottom side")) {
            HStack(alignment: .top, spacing: 16) {
                playerField(
                    title: String(localized: "Left side"),
                    subtitle: String(localized: "Left side"),
                    text: $sideAPlayer2
                )
                playerField(
                    title: String(localized: "Right side"),
                    subtitle: String(localized: "Right side"),
                    text: $sideAPlayer1
                )
            }
        }
        .onAppear(perform: loadFromMatch)
        .onDisappear(perform: saveIfNeeded)
        .onChange(of: scenePhase) { _, newPhase in
            // `onDisappear` isn't guaranteed when the app is backgrounded or
            // killed, so also persist edits when leaving the active state.
            if newPhase != .active {
                saveIfNeeded()
            }
        }
    }

    private func playerField(title: String, subtitle: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(title, text: text)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .accessibilityLabel(String(localized: "\(subtitle), \(title)"))
                .onSubmit(saveIfNeeded)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func loadFromMatch() {
        sideAPlayer1 = match.playerA1Name ?? ""
        sideAPlayer2 = match.playerA2Name ?? ""
        sideBPlayer1 = match.playerB1Name ?? ""
        sideBPlayer2 = match.playerB2Name ?? ""
    }

    private func saveIfNeeded() {
        let setup = MatchPlayerSetup(
            sideAPlayer1: slotSelection(name: sideAPlayer1, storedName: match.playerA1Name, storedID: match.playerA1ID),
            sideAPlayer2: slotSelection(name: sideAPlayer2, storedName: match.playerA2Name, storedID: match.playerA2ID),
            sideBPlayer1: slotSelection(name: sideBPlayer1, storedName: match.playerB1Name, storedID: match.playerB1ID),
            sideBPlayer2: slotSelection(name: sideBPlayer2, storedName: match.playerB2Name, storedID: match.playerB2ID)
        )

        let normalized = (
            setup.sideAPlayer1.trimmedName,
            setup.sideAPlayer2.trimmedName,
            setup.sideBPlayer1.trimmedName,
            setup.sideBPlayer2.trimmedName
        )
        let current = (
            match.playerA1Name ?? "",
            match.playerA2Name ?? "",
            match.playerB1Name ?? "",
            match.playerB2Name ?? ""
        )
        guard normalized != current else { return }

        PlayerPersistence.updateMatchPlayers(context: modelContext, match: match, setup: setup)
        syncCoordinator.syncPhoneContextToWatch()
    }

    private func slotSelection(name: String, storedName: String?, storedID: UUID?) -> MatchPlayerSlotSelection {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let unchanged = trimmed == (storedName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return MatchPlayerSlotSelection(name: name, playerID: unchanged ? storedID : nil)
    }
}
