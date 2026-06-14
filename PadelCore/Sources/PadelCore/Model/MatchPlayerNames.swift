import Foundation

/// Optional player names for a doubles match (two per side).
public struct MatchPlayerNames: Codable, Hashable, Sendable {
    public var playerA1Name: String?
    public var playerA2Name: String?
    public var playerB1Name: String?
    public var playerB2Name: String?
    /// Legacy whole-side label when individual player names were not captured.
    public var teamAName: String?
    public var teamBName: String?

    public static let empty = MatchPlayerNames()

    public init(
        playerA1Name: String? = nil,
        playerA2Name: String? = nil,
        playerB1Name: String? = nil,
        playerB2Name: String? = nil,
        teamAName: String? = nil,
        teamBName: String? = nil
    ) {
        self.playerA1Name = playerA1Name?.nilIfEmpty
        self.playerA2Name = playerA2Name?.nilIfEmpty
        self.playerB1Name = playerB1Name?.nilIfEmpty
        self.playerB2Name = playerB2Name?.nilIfEmpty
        self.teamAName = teamAName?.nilIfEmpty
        self.teamBName = teamBName?.nilIfEmpty
    }

    public init(
        playerA1: String,
        playerA2: String,
        playerB1: String,
        playerB2: String
    ) {
        self.init(
            playerA1Name: playerA1,
            playerA2Name: playerA2,
            playerB1Name: playerB1,
            playerB2Name: playerB2
        )
    }

    public func players(for team: Team) -> [String] {
        switch team {
        case .a:
            [playerA1Name, playerA2Name].compactMap { $0 }
        case .b:
            [playerB1Name, playerB2Name].compactMap { $0 }
        }
    }

    public func sideLabel(for team: Team) -> String {
        let names = players(for: team)
        if !names.isEmpty {
            return names.joined(separator: " · ")
        }

        switch team {
        case .a:
            return teamAName ?? String(localized: "Team A")
        case .b:
            return teamBName ?? String(localized: "Team B")
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
