import Foundation
import SwiftData

@Model
public final class Match {
    @Attribute(.unique) public var id: UUID
    public var startedAt: Date
    public var endedAt: Date?
    public var rulesData: Data
    public var completedSetsData: Data
    public var winnerRawValue: String?
    public var teamAName: String?
    public var teamBName: String?

    @Relationship(deleteRule: .cascade, inverse: \StoredPointEvent.match)
    public var points: [StoredPointEvent]

    public init(
        id: UUID = UUID(),
        startedAt: Date = .now,
        endedAt: Date? = nil,
        rules: MatchRules = .default,
        completedSets: [SetScore] = [],
        winner: Team? = nil,
        teamAName: String? = nil,
        teamBName: String? = nil,
        points: [StoredPointEvent] = []
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.rulesData = (try? JSONEncoder().encode(rules)) ?? Data()
        self.completedSetsData = (try? JSONEncoder().encode(completedSets)) ?? Data()
        self.winnerRawValue = winner?.rawValue
        self.teamAName = teamAName
        self.teamBName = teamBName
        self.points = points
    }

    public var rules: MatchRules {
        get {
            (try? JSONDecoder().decode(MatchRules.self, from: rulesData)) ?? .default
        }
        set {
            rulesData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    public var completedSets: [SetScore] {
        get {
            (try? JSONDecoder().decode([SetScore].self, from: completedSetsData)) ?? []
        }
        set {
            completedSetsData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    public var winner: Team? {
        get { winnerRawValue.flatMap(Team.init(rawValue:)) }
        set { winnerRawValue = newValue?.rawValue }
    }

    public var duration: TimeInterval? {
        guard let endedAt else { return nil }
        return endedAt.timeIntervalSince(startedAt)
    }

    public var scoreSummary: String {
        completedSets.map { ScoreFormatter.formatSetScore($0) }.joined(separator: " ")
    }

    public var sortedPoints: [StoredPointEvent] {
        points.sorted { $0.sequence < $1.sequence }
    }

    public var enginePointEvents: [PointEvent] {
        sortedPoints.map { PointEvent(team: $0.team) }
    }

    public func replayedState() -> MatchState {
        ScoringEngine.replay(events: enginePointEvents, rules: rules)
    }
}
