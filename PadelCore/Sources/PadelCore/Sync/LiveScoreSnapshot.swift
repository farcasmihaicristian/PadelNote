import Foundation

/// Compact live score payload for WatchConnectivity application context.
public struct LiveScoreSnapshot: Codable, Hashable, Sendable {
    public let matchID: UUID
    public let gameScore: String
    public let setGames: String
    public let completedSetScores: [String]
    public let isMatchOver: Bool
    public let teamAName: String?
    public let teamBName: String?
    public let pointCount: Int
    public let updatedAt: Date

    public init(
        matchID: UUID,
        state: MatchState,
        teamAName: String?,
        teamBName: String?,
        pointCount: Int,
        updatedAt: Date = .now
    ) {
        self.matchID = matchID
        self.gameScore = ScoreFormatter.currentGameScore(in: state)
        self.setGames = ScoreFormatter.currentSetGames(in: state)
        self.completedSetScores = state.completedSets.map { ScoreFormatter.formatSetScore($0) }
        self.isMatchOver = state.isMatchOver
        self.teamAName = teamAName?.nilIfEmpty
        self.teamBName = teamBName?.nilIfEmpty
        self.pointCount = pointCount
        self.updatedAt = updatedAt
    }

    public var scoreLine: String {
        var parts = completedSetScores
        if !isMatchOver {
            parts.append("\(setGames) \(gameScore)")
        }
        return parts.joined(separator: " ")
    }

    public func teamLabel(for team: Team) -> String {
        switch team {
        case .a:
            teamAName ?? String(localized: "Team A")
        case .b:
            teamBName ?? String(localized: "Team B")
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
