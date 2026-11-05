import PadelCore
import SwiftUI

/// Who played, described from your side of the net when you're in the match.
struct MatchPlayersSection: View {
    let match: Match
    let perspective: MatchPerspective?
    let onEdit: () -> Void

    var body: some View {
        let names = match.playerNames

        if let perspective {
            Section(String(localized: "You & partner")) {
                playerRow(
                    name: names.name(for: perspective.mySlot),
                    isMe: true,
                    detail: perspective.mySlot.defaultCourtSide.label
                )
                playerRow(
                    name: names.name(for: perspective.partnerSlot),
                    detail: perspective.partnerSlot.defaultCourtSide.label
                )
            }

            Section(String(localized: "Opponents")) {
                playerRow(
                    name: names.name(for: perspective.acrossSlot),
                    detail: String(localized: "Across from you")
                )
                playerRow(
                    name: names.name(for: perspective.diagonalSlot),
                    detail: String(localized: "Diagonal to you")
                )
                editButton
            }
        } else {
            teamSection(.a, names: names)
            Section {
                teamRows(.b, names: names)
                editButton
            } header: {
                Text(PlayerRoleLabels.teamTitle(for: .b))
            } footer: {
                Text(String(localized: "Set up your profile in Settings to see who played across from you and diagonal to you."))
            }
        }
    }

    private func teamSection(_ team: Team, names: MatchPlayerNames) -> some View {
        Section(PlayerRoleLabels.teamTitle(for: team)) {
            teamRows(team, names: names)
        }
    }

    @ViewBuilder
    private func teamRows(_ team: Team, names: MatchPlayerNames) -> some View {
        let slots: [PlayerSlot] = team == .a ? [.sideAPlayer1, .sideAPlayer2] : [.sideBPlayer1, .sideBPlayer2]
        ForEach(slots) { slot in
            playerRow(name: names.name(for: slot), detail: slot.defaultCourtSide.label)
        }
    }

    private var editButton: some View {
        Button(action: onEdit) {
            Label(String(localized: "Edit players"), systemImage: "pencil")
        }
    }

    private func playerRow(name: String?, isMe: Bool = false, detail: String) -> some View {
        LabeledContent {
            Text(detail)
        } label: {
            HStack(spacing: 6) {
                Text(name ?? String(localized: "Not set"))
                    .foregroundStyle(name == nil ? .secondary : .primary)
                    .fontWeight(isMe ? .semibold : .regular)
                if isMe {
                    Text(String(localized: "You"))
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.tint.opacity(0.15), in: Capsule())
                        .foregroundStyle(.tint)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
