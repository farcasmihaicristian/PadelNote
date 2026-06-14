import Foundation

/// Compact live score payload for WatchConnectivity application context.
public struct LiveScoreSnapshot: Codable, Hashable, Sendable {
    public let matchID: UUID
    public let gameScore: String
    public let setGames: String
    public let completedSetScores: [String]
    public let isMatchOver: Bool
    public let playerA1Name: String?
    public let playerA2Name: String?
    public let playerB1Name: String?
    public let playerB2Name: String?
    public let teamAName: String?
    public let teamBName: String?
    public let pointCount: Int
    public let updatedAt: Date
    public let isSessionActive: Bool

    public var playerNames: MatchPlayerNames {
        MatchPlayerNames(
            playerA1Name: playerA1Name,
            playerA2Name: playerA2Name,
            playerB1Name: playerB1Name,
            playerB2Name: playerB2Name,
            teamAName: teamAName,
            teamBName: teamBName
        )
    }

    public init(
        matchID: UUID,
        state: MatchState,
        playerNames: MatchPlayerNames = .empty,
        pointCount: Int,
        updatedAt: Date = .now,
        isSessionActive: Bool = true
    ) {
        self.matchID = matchID
        self.gameScore = ScoreFormatter.currentGameScore(in: state)
        self.setGames = ScoreFormatter.currentSetGames(in: state)
        self.completedSetScores = state.completedSets.map { ScoreFormatter.formatSetScore($0) }
        self.isMatchOver = state.isMatchOver
        self.playerA1Name = playerNames.playerA1Name
        self.playerA2Name = playerNames.playerA2Name
        self.playerB1Name = playerNames.playerB1Name
        self.playerB2Name = playerNames.playerB2Name
        self.teamAName = playerNames.teamAName
        self.teamBName = playerNames.teamBName
        self.pointCount = pointCount
        self.updatedAt = updatedAt
        self.isSessionActive = isSessionActive
    }

    public static func sessionEnded(matchID: UUID) -> LiveScoreSnapshot {
        LiveScoreSnapshot(
            matchID: matchID,
            gameScore: "0-0",
            setGames: "0-0",
            completedSetScores: [],
            isMatchOver: false,
            playerNames: .empty,
            pointCount: 0,
            updatedAt: .now,
            isSessionActive: false
        )
    }

    public init(
        matchID: UUID,
        gameScore: String,
        setGames: String,
        completedSetScores: [String],
        isMatchOver: Bool,
        playerNames: MatchPlayerNames = .empty,
        pointCount: Int,
        updatedAt: Date,
        isSessionActive: Bool
    ) {
        self.matchID = matchID
        self.gameScore = gameScore
        self.setGames = setGames
        self.completedSetScores = completedSetScores
        self.isMatchOver = isMatchOver
        self.playerA1Name = playerNames.playerA1Name
        self.playerA2Name = playerNames.playerA2Name
        self.playerB1Name = playerNames.playerB1Name
        self.playerB2Name = playerNames.playerB2Name
        self.teamAName = playerNames.teamAName
        self.teamBName = playerNames.teamBName
        self.pointCount = pointCount
        self.updatedAt = updatedAt
        self.isSessionActive = isSessionActive
    }

    public var isVisibleOnPhone: Bool {
        isSessionActive && !isMatchOver
    }

    private enum CodingKeys: String, CodingKey {
        case matchID
        case gameScore
        case setGames
        case completedSetScores
        case isMatchOver
        case playerA1Name
        case playerA2Name
        case playerB1Name
        case playerB2Name
        case teamAName
        case teamBName
        case pointCount
        case updatedAt
        case isSessionActive
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        matchID = try container.decode(UUID.self, forKey: .matchID)
        gameScore = try container.decode(String.self, forKey: .gameScore)
        setGames = try container.decode(String.self, forKey: .setGames)
        completedSetScores = try container.decode([String].self, forKey: .completedSetScores)
        isMatchOver = try container.decode(Bool.self, forKey: .isMatchOver)
        playerA1Name = try container.decodeIfPresent(String.self, forKey: .playerA1Name)
        playerA2Name = try container.decodeIfPresent(String.self, forKey: .playerA2Name)
        playerB1Name = try container.decodeIfPresent(String.self, forKey: .playerB1Name)
        playerB2Name = try container.decodeIfPresent(String.self, forKey: .playerB2Name)
        teamAName = try container.decodeIfPresent(String.self, forKey: .teamAName)
        teamBName = try container.decodeIfPresent(String.self, forKey: .teamBName)
        pointCount = try container.decode(Int.self, forKey: .pointCount)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        isSessionActive = try container.decodeIfPresent(Bool.self, forKey: .isSessionActive) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(matchID, forKey: .matchID)
        try container.encode(gameScore, forKey: .gameScore)
        try container.encode(setGames, forKey: .setGames)
        try container.encode(completedSetScores, forKey: .completedSetScores)
        try container.encode(isMatchOver, forKey: .isMatchOver)
        try container.encodeIfPresent(playerA1Name, forKey: .playerA1Name)
        try container.encodeIfPresent(playerA2Name, forKey: .playerA2Name)
        try container.encodeIfPresent(playerB1Name, forKey: .playerB1Name)
        try container.encodeIfPresent(playerB2Name, forKey: .playerB2Name)
        try container.encodeIfPresent(teamAName, forKey: .teamAName)
        try container.encodeIfPresent(teamBName, forKey: .teamBName)
        try container.encode(pointCount, forKey: .pointCount)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(isSessionActive, forKey: .isSessionActive)
    }

    public var scoreLine: String {
        var parts = completedSetScores
        if !isMatchOver {
            parts.append("\(setGames) \(gameScore)")
        }
        return parts.joined(separator: " ")
    }

    public func teamLabel(for team: Team) -> String {
        playerNames.sideLabel(for: team)
    }
}
