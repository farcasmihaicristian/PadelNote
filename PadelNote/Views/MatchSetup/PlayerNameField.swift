import PadelCore
import SwiftData
import SwiftUI

struct PlayerNameField: View {
    @Binding var selection: MatchPlayerSlotSelection
    let label: String
    let knownNames: [String]
    let linkedPlayers: [Player]

    private var menuSelectionLabel: String {
        let trimmed = selection.trimmedName
        if trimmed.isEmpty {
            return String(localized: "None")
        }
        return trimmed
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !knownNames.isEmpty {
                LabeledContent(String(localized: "Known players")) {
                    Menu {
                        Button(String(localized: "None")) {
                            selection = MatchPlayerSlotSelection()
                        }

                        ForEach(knownNames, id: \.self) { name in
                            Button(name) {
                                selection.name = name
                                selection.playerID = linkedPlayers.first(where: {
                                    PlayerPersistence.normalizeName($0.displayName)
                                        == PlayerPersistence.normalizeName(name)
                                })?.id
                            }
                        }
                    } label: {
                        Text(menuSelectionLabel)
                            .foregroundStyle(selection.hasContent ? .primary : .secondary)
                    }
                    .accessibilityLabel(String(localized: "Known players for \(label)"))
                }
            }

            TextField(String(localized: "Or enter name"), text: $selection.name, prompt: Text(label))
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .accessibilityLabel(label)
                .onChange(of: selection.name) { _, newValue in
                    syncPlayerID(for: newValue)
                }
        }
    }

    private func syncPlayerID(for name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            selection.playerID = nil
            return
        }

        if let playerID = selection.playerID,
           let player = linkedPlayers.first(where: { $0.id == playerID }),
           PlayerPersistence.normalizeName(player.displayName)
               == PlayerPersistence.normalizeName(trimmed) {
            return
        }

        if let player = linkedPlayers.first(where: {
            PlayerPersistence.normalizeName($0.displayName)
                == PlayerPersistence.normalizeName(trimmed)
        }) {
            selection.playerID = player.id
        } else {
            selection.playerID = nil
        }
    }
}

private extension MatchPlayerSlotSelection {
    var hasContent: Bool {
        !trimmedName.isEmpty || playerID != nil
    }
}
