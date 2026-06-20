import Foundation

public struct RolePerformanceStats: Sendable, Hashable {
    public let matchCount: Int
    public let wins: Int
    public let losses: Int
    public let winRate: Double?

    public static let empty = RolePerformanceStats(
        matchCount: 0,
        wins: 0,
        losses: 0,
        winRate: nil
    )

    public init(matchCount: Int, wins: Int, losses: Int, winRate: Double?) {
        self.matchCount = matchCount
        self.wins = wins
        self.losses = losses
        self.winRate = winRate
    }
}

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
    public let leftSideStats: RolePerformanceStats
    public let rightSideStats: RolePerformanceStats
    /// Points played on the player's own serve.
    public let servePointsPlayed: Int
    /// Of those, points the serving team won.
    public let servePointsWon: Int
    public let servePointWinRate: Double?
    /// Service games the player served (tie-breaks excluded).
    public let serviceGamesPlayed: Int
    /// Service games the player's team held.
    public let serviceGamesHeld: Int
    /// Service games the player's team was broken.
    public let serviceGamesBroken: Int
    public let serviceHoldRate: Double?

    public init(
        playerID: UUID,
        displayName: String,
        matchCount: Int,
        decidedMatchCount: Int,
        wins: Int,
        losses: Int,
        winRate: Double?,
        averageDuration: TimeInterval?,
        goldenPointOpportunities: Int,
        goldenPointWins: Int,
        goldenPointConversionRate: Double?,
        leftSideStats: RolePerformanceStats,
        rightSideStats: RolePerformanceStats,
        servePointsPlayed: Int = 0,
        servePointsWon: Int = 0,
        servePointWinRate: Double? = nil,
        serviceGamesPlayed: Int = 0,
        serviceGamesHeld: Int = 0,
        serviceGamesBroken: Int = 0,
        serviceHoldRate: Double? = nil
    ) {
        self.playerID = playerID
        self.displayName = displayName
        self.matchCount = matchCount
        self.decidedMatchCount = decidedMatchCount
        self.wins = wins
        self.losses = losses
        self.winRate = winRate
        self.averageDuration = averageDuration
        self.goldenPointOpportunities = goldenPointOpportunities
        self.goldenPointWins = goldenPointWins
        self.goldenPointConversionRate = goldenPointConversionRate
        self.leftSideStats = leftSideStats
        self.rightSideStats = rightSideStats
        self.servePointsPlayed = servePointsPlayed
        self.servePointsWon = servePointsWon
        self.servePointWinRate = servePointWinRate
        self.serviceGamesPlayed = serviceGamesPlayed
        self.serviceGamesHeld = serviceGamesHeld
        self.serviceGamesBroken = serviceGamesBroken
        self.serviceHoldRate = serviceHoldRate
    }

    /// True when any serve data was recorded for this player.
    public var hasServeData: Bool {
        servePointsPlayed > 0 || serviceGamesPlayed > 0
    }

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
            goldenPointConversionRate: nil,
            leftSideStats: .empty,
            rightSideStats: .empty
        )
    }
}
