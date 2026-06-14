import Foundation

public struct PlayerSummary: Sendable, Hashable, Identifiable {
    public let id: UUID
    public let displayName: String
    public let matchCount: Int
    public let wins: Int
    public let losses: Int
    public let winRate: Double?

    public init(
        id: UUID,
        displayName: String,
        matchCount: Int,
        wins: Int,
        losses: Int,
        winRate: Double?
    ) {
        self.id = id
        self.displayName = displayName
        self.matchCount = matchCount
        self.wins = wins
        self.losses = losses
        self.winRate = winRate
    }
}

public struct PartnerSummary: Sendable, Hashable, Identifiable {
    public let id: UUID
    public let displayName: String
    public let matchCount: Int
    public let wins: Int
    public let losses: Int
    public let winRate: Double?

    public init(
        id: UUID,
        displayName: String,
        matchCount: Int,
        wins: Int,
        losses: Int,
        winRate: Double?
    ) {
        self.id = id
        self.displayName = displayName
        self.matchCount = matchCount
        self.wins = wins
        self.losses = losses
        self.winRate = winRate
    }
}

public struct PlayerInsights: Sendable, Hashable {
    public let playerID: UUID
    public let displayName: String
    public let matchCount: Int
    public let decidedMatchCount: Int
    public let wins: Int
    public let losses: Int
    public let winRate: Double?
    public let averageDuration: TimeInterval?
    public let goldenPointOpportunities: Int
    public let goldenPointWins: Int
    public let goldenPointConversionRate: Double?

    public static func empty(playerID: UUID, displayName: String) -> PlayerInsights {
        PlayerInsights(
            playerID: playerID,
            displayName: displayName,
            matchCount: 0,
            decidedMatchCount: 0,
            wins: 0,
            losses: 0,
            winRate: nil,
            averageDuration: nil,
            goldenPointOpportunities: 0,
            goldenPointWins: 0,
            goldenPointConversionRate: nil
        )
    }
}
