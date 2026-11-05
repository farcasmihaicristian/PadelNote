import Foundation
import PadelCore

/// User-facing names for a player's position, from your point of view when
/// you're in the match, otherwise by team.
enum PlayerRoleLabels {
    static func role(for slot: PlayerSlot, perspective: MatchPerspective?) -> String {
        guard let perspective else {
            return "\(teamTitle(for: slot.team)) · \(slot.defaultCourtSide.label)"
        }
        switch slot {
        case perspective.mySlot:
            return String(localized: "You")
        case perspective.partnerSlot:
            return String(localized: "Partner")
        case perspective.acrossSlot:
            return String(localized: "Across from you")
        default:
            return String(localized: "Diagonal to you")
        }
    }

    static func teamTitle(for team: Team) -> String {
        switch team {
        case .a: String(localized: "Team 1")
        case .b: String(localized: "Team 2")
        }
    }

    /// Slot order for listing: you, partner, then opponents across and diagonal.
    static func orderedSlots(perspective: MatchPerspective?) -> [PlayerSlot] {
        guard let perspective else {
            return [.sideAPlayer1, .sideAPlayer2, .sideBPlayer1, .sideBPlayer2]
        }
        return [perspective.mySlot, perspective.partnerSlot, perspective.acrossSlot, perspective.diagonalSlot]
    }
}
