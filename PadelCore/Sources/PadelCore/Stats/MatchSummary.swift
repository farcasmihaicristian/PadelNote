import Foundation

public struct MatchSummary: Sendable, Hashable {
    public let rules: MatchRules
    public let events: [PointEvent]
    public let winner: Team?
    public let duration: TimeInterval?
    public let isCompleted: Bool
    public let roster: MatchRoster

    public init(
        rules: MatchRules,
        events: [PointEvent],
        winner: Team?,
        duration: TimeInterval?,
        isCompleted: Bool,
        roster: MatchRoster = .empty
    ) {
        self.rules = rules
        self.events = events
        self.winner = winner
        self.duration = duration
        self.isCompleted = isCompleted
        self.roster = roster
    }
}
