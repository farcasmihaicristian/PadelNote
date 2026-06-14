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
    public var playerA1Name: String?
    public var playerA2Name: String?
    public var playerB1Name: String?
    public var playerB2Name: String?
    public var teamAName: String?
    public var teamBName: String?
    public var averageHeartRate: Double?
    public var activeEnergyKilocalories: Double?
    public var distanceMeters: Double?

    @Relationship(deleteRule: .cascade, inverse: \StoredPointEvent.match)
    public var points: [StoredPointEvent]

    public init(
        id: UUID = UUID(),
        startedAt: Date = .now,
        endedAt: Date? = nil,
        rules: MatchRules = .default,
        completedSets: [SetScore] = [],
        winner: Team? = nil,
        playerNames: MatchPlayerNames = .empty,
        averageHeartRate: Double? = nil,
        activeEnergyKilocalories: Double? = nil,
        distanceMeters: Double? = nil,
        points: [StoredPointEvent] = []
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.rulesData = (try? JSONEncoder().encode(rules)) ?? Data()
        self.completedSetsData = (try? JSONEncoder().encode(completedSets)) ?? Data()
        self.winnerRawValue = winner?.rawValue
        self.playerA1Name = playerNames.playerA1Name
        self.playerA2Name = playerNames.playerA2Name
        self.playerB1Name = playerNames.playerB1Name
        self.playerB2Name = playerNames.playerB2Name
        self.teamAName = playerNames.teamAName
        self.teamBName = playerNames.teamBName
        self.averageHeartRate = averageHeartRate
        self.activeEnergyKilocalories = activeEnergyKilocalories
        self.distanceMeters = distanceMeters
        self.points = points
    }

    public var playerNames: MatchPlayerNames {
        get {
            MatchPlayerNames(
                playerA1Name: playerA1Name,
                playerA2Name: playerA2Name,
                playerB1Name: playerB1Name,
                playerB2Name: playerB2Name,
                teamAName: teamAName,
                teamBName: teamBName
            )
        }
        set {
            playerA1Name = newValue.playerA1Name
            playerA2Name = newValue.playerA2Name
            playerB1Name = newValue.playerB1Name
            playerB2Name = newValue.playerB2Name
            teamAName = newValue.teamAName
            teamBName = newValue.teamBName
        }
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

    public var isCompleted: Bool {
        endedAt != nil && !sortedPoints.isEmpty
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

    public func scoreLine(afterPointCount count: Int) -> String {
        let events = Array(enginePointEvents.prefix(count))
        let state = ScoringEngine.replay(events: events, rules: rules)
        return ScoreFormatter.matchScoreLine(in: state)
    }

    public func players(for team: Team) -> [String] {
        playerNames.players(for: team)
    }

    public func sideLabel(for team: Team) -> String {
        playerNames.sideLabel(for: team)
    }

    public func teamName(for team: Team) -> String {
        sideLabel(for: team)
    }

    public var summary: MatchSummary {
        MatchSummary(
            rules: rules,
            events: enginePointEvents,
            winner: winner,
            duration: duration,
            isCompleted: isCompleted
        )
    }
}
