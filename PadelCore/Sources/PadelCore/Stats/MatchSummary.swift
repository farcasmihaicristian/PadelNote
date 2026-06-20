import Foundation

public struct MatchSummary: Sendable, Hashable {
    public let rules: MatchRules
    public let events: [PointEvent]
    public let winner: Team?
    public let duration: TimeInterval?
    public let isCompleted: Bool
    public let roster: MatchRoster
    /// Court lineup per set (index = set number). Empty for matches without
    /// per-set tracking; consumers fall back to `roster` for every set.
    public let setRosters: [MatchRoster]
    /// Serving order per set (index = set number). Empty for matches recorded
    /// without serve tracking.
    public let setServeOrders: [ServeOrder]

    public init(
        rules: MatchRules,
        events: [PointEvent],
        winner: Team?,
        duration: TimeInterval?,
        isCompleted: Bool,
        roster: MatchRoster = .empty,
        setRosters: [MatchRoster] = [],
        setServeOrders: [ServeOrder] = []
    ) {
        self.rules = rules
        self.events = events
        self.winner = winner
        self.duration = duration
        self.isCompleted = isCompleted
        self.roster = roster
        self.setRosters = setRosters
        self.setServeOrders = setServeOrders
    }
}
