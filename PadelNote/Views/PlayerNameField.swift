import PadelCore
import SwiftData
import SwiftUI

struct PlayerNameField: View {
    @Binding var selection: MatchPlayerSlotSelection
    let label: String
    let players: [Player]

    private var suggestions: [Player] {
        let trimmed = selection.trimmedName
        guard !trimmed.isEmpty, selection.playerID == nil else { return [] }

        let normalizedQuery = PlayerPersistence.normalizeName(trimmed)
        return players
            .filter { player in
                player.normalizedName.contains(normalizedQuery)
                    || player.displayName.localizedCaseInsensitiveContains(trimmed)
            }
            .prefix(5)
            .map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField(label, text: $selection.name)
                .accessibilityLabel(label)
                .onChange(of: selection.name) { _, newValue in
                    guard let playerID = selection.playerID,
                          let player = players.first(where: { $0.id == playerID })
                    else { return }

                    if PlayerPersistence.normalizeName(newValue) != player.normalizedName {
                        selection.playerID = nil
                    }
                }

            if !suggestions.isEmpty {
                ForEach(suggestions, id: \.id) { player in
                    Button {
                        selection.name = player.displayName
                        selection.playerID = player.id
                    } label: {
                        HStack {
                            Text(player.displayName)
                                .foregroundStyle(.primary)
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(
                        String(localized: "Use existing player \(player.displayName)")
                    )
                }
            }
        }
    }
}
