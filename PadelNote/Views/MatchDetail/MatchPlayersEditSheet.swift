import PadelCore
import SwiftData
import SwiftUI

/// Edit player names by court position. The court is drawn from your side
/// when you're in the match; tapping a player jumps to their name field.
struct MatchPlayersEditSheet: View {
    let match: Match
    let perspective: MatchPerspective?

    @Environment(\.modelContext) private var modelContext
    @Environment(PhoneSyncCoordinator.self) private var syncCoordinator
    @Environment(\.dismiss) private var dismiss

    @State private var names: [PlayerSlot: String] = [:]
    @FocusState private var focusedSlot: PlayerSlot?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    CourtDiagramView(
                        bottomTeam: perspective?.myTeam ?? .a,
                        name: { slot in
                            let trimmed = (names[slot] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                            return trimmed.isEmpty ? nil : trimmed
                        },
                        caption: { PlayerRoleLabels.role(for: $0, perspective: perspective) },
                        highlightedSlot: perspective?.mySlot,
                        onSelect: { focusedSlot = $0 }
                    )
                    .listRowInsets(EdgeInsets())
                } footer: {
                    Text(String(localized: "Tap a player to edit their name."))
                }

                Section(String(localized: "Players")) {
                    ForEach(PlayerRoleLabels.orderedSlots(perspective: perspective)) { slot in
                        nameField(for: slot)
                    }
                }
            }
            .navigationTitle(String(localized: "Edit players"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Save")) {
                        save()
                        dismiss()
                    }
                }
            }
            .onAppear(perform: loadFromMatch)
        }
    }

    private func nameField(for slot: PlayerSlot) -> some View {
        let role = PlayerRoleLabels.role(for: slot, perspective: perspective)
        return LabeledContent(role) {
            TextField(
                String(localized: "Name"),
                text: Binding(
                    get: { names[slot] ?? "" },
                    set: { names[slot] = $0 }
                )
            )
            .multilineTextAlignment(.trailing)
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled()
            .focused($focusedSlot, equals: slot)
            .submitLabel(.next)
            .onSubmit(focusNextField)
        }
        .accessibilityLabel(role)
    }

    private func focusNextField() {
        let order = PlayerRoleLabels.orderedSlots(perspective: perspective)
        guard let current = focusedSlot, let index = order.firstIndex(of: current) else { return }
        focusedSlot = index + 1 < order.count ? order[index + 1] : nil
    }

    private func loadFromMatch() {
        let current = match.playerNames
        for slot in PlayerSlot.allCases {
            names[slot] = current.name(for: slot) ?? ""
        }
    }

    private func save() {
        let storedIDs: [PlayerSlot: UUID?] = [
            .sideAPlayer1: match.playerA1ID,
            .sideAPlayer2: match.playerA2ID,
            .sideBPlayer1: match.playerB1ID,
            .sideBPlayer2: match.playerB2ID,
        ]
        let storedNames = match.playerNames

        var setup = MatchPlayerSetup.empty
        var changed = false
        for slot in PlayerSlot.allCases {
            let edited = (names[slot] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let stored = storedNames.name(for: slot) ?? ""
            let unchanged = edited == stored
            changed = changed || !unchanged
            slot.applySelection(
                MatchPlayerSlotSelection(name: edited, playerID: unchanged ? storedIDs[slot] ?? nil : nil),
                to: &setup
            )
        }
        guard changed else { return }

        PlayerPersistence.updateMatchPlayers(context: modelContext, match: match, setup: setup)
        syncCoordinator.syncPhoneContextToWatch()
    }
}
