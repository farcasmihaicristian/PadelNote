import Foundation

public struct MatchInsights: Sendable, Hashable {
    public let completedMatchCount: Int
    public let decidedMatchCount: Int
    public let teamAWins: Int
    public let teamBWins: Int
    /// Share of decided matches won by Team A (0…1), nil when no decided matches.
    public let teamAWinRate: Double?
    public let averageDuration: TimeInterval?
    public let longestDuration: TimeInterval?
    public let goldenPointOpportunities: Int
    public let goldenPointWinsByTeamA: Int
    /// Team A golden-point conversion (0…1), nil when no golden-point situations occurred.
    public let goldenPointConversionRate: Double?

    public static let empty = MatchInsights(
        completedMatchCount: 0,
        decidedMatchCount: 0,
        teamAWins: 0,
        teamBWins: 0,
        teamAWinRate: nil,
        averageDuration: nil,
        longestDuration: nil,
        goldenPointOpportunities: 0,
        goldenPointWinsByTeamA: 0,
        goldenPointConversionRate: nil
    )
}
