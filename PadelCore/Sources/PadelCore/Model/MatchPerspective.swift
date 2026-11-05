import Foundation

/// A match seen from one player's position: who partnered them and where each
/// opponent stood relative to them across the net.
public struct MatchPerspective: Sendable, Hashable {
    public let mySlot: PlayerSlot

    public init(mySlot: PlayerSlot) {
        self.mySlot = mySlot
    }

    /// Locates `mePlayerID` in the roster by linked player ID, falling back to a
    /// case/whitespace-insensitive name match for unlinked matches.
    public init?(roster: MatchRoster, mePlayerID: UUID?, meName: String? = nil) {
        let slots: [(PlayerSlot, MatchPlayerRosterEntry)] = [
            (.sideAPlayer1, roster.sideA[safe: 0] ?? .init()),
            (.sideAPlayer2, roster.sideA[safe: 1] ?? .init()),
            (.sideBPlayer1, roster.sideB[safe: 0] ?? .init()),
            (.sideBPlayer2, roster.sideB[safe: 1] ?? .init()),
        ]

        if let mePlayerID, let match = slots.first(where: { $0.1.id == mePlayerID }) {
            self.init(mySlot: match.0)
            return
        }

        let normalizedMe = meName.map(Self.normalize) ?? ""
        guard !normalizedMe.isEmpty,
              let match = slots.first(where: { $0.1.name.map(Self.normalize) == normalizedMe })
        else { return nil }
        self.init(mySlot: match.0)
    }

    public var myTeam: Team { mySlot.team }

    public var partnerSlot: PlayerSlot { mySlot.partner }

    /// The opponent standing directly in front of you across the net. Opponents
    /// face the other way, so your right side lines up with their left side.
    public var acrossSlot: PlayerSlot {
        Self.slot(team: myTeam.opponent, side: mySlot.defaultCourtSide.opposite)
    }

    /// The cross-court opponent on the same side as you (who you return serve against).
    public var diagonalSlot: PlayerSlot {
        Self.slot(team: myTeam.opponent, side: mySlot.defaultCourtSide)
    }

    static func slot(team: Team, side: PlayerCourtSide) -> PlayerSlot {
        switch (team, side) {
        case (.a, .right): .sideAPlayer1
        case (.a, .left): .sideAPlayer2
        case (.b, .right): .sideBPlayer1
        case (.b, .left): .sideBPlayer2
        }
    }

    private static func normalize(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

/// Screen placement of the four slots on a vertical court diagram.
public enum CourtDiagramLayout {
    /// Slots left-to-right for each half, with `bottomTeam` drawn nearest the
    /// viewer. The far team faces the viewer, so its right side is screen-left.
    public static func rows(bottomTeam: Team) -> (top: [PlayerSlot], bottom: [PlayerSlot]) {
        let topTeam = bottomTeam.opponent
        return (
            top: [
                MatchPerspective.slot(team: topTeam, side: .right),
                MatchPerspective.slot(team: topTeam, side: .left),
            ],
            bottom: [
                MatchPerspective.slot(team: bottomTeam, side: .left),
                MatchPerspective.slot(team: bottomTeam, side: .right),
            ]
        )
    }
}

public extension PlayerCourtSide {
    var opposite: PlayerCourtSide {
        self == .left ? .right : .left
    }
}

public extension MatchPlayerNames {
    func name(for slot: PlayerSlot) -> String? {
        let raw: String? = switch slot {
        case .sideAPlayer1: playerA1Name
        case .sideAPlayer2: playerA2Name
        case .sideBPlayer1: playerB1Name
        case .sideBPlayer2: playerB2Name
        }
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}
