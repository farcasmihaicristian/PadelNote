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
    public var playerA1ID: UUID?
    public var playerA2ID: UUID?
    public var playerB1ID: UUID?
    public var playerB2ID: UUID?
    public var teamAName: String?
    public var teamBName: String?
    public var averageHeartRate: Double?
    public var activeEnergyKilocalories: Double?
    public var distanceMeters: Double?
    /// JSON-encoded `[MatchRoster]`, one entry per set, capturing left/right
    /// side changes made between sets. Empty for matches without per-set tracking.
    public var setRostersData: Data = Data()

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
        roster: MatchRoster = .empty,
        averageHeartRate: Double? = nil,
        activeEnergyKilocalories: Double? = nil,
        distanceMeters: Double? = nil,
        setRosters: [MatchRoster] = [],
        points: [StoredPointEvent] = []
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.rulesData = (try? JSONEncoder().encode(rules)) ?? Data()
        self.completedSetsData = (try? JSONEncoder().encode(completedSets)) ?? Data()
        self.winnerRawValue = winner?.rawValue
        self.playerA1Name = playerNames.playerA1Name ?? roster.sideA[safe: 0]?.name
        self.playerA2Name = playerNames.playerA2Name ?? roster.sideA[safe: 1]?.name
        self.playerB1Name = playerNames.playerB1Name ?? roster.sideB[safe: 0]?.name
        self.playerB2Name = playerNames.playerB2Name ?? roster.sideB[safe: 1]?.name
        self.playerA1ID = roster.sideA[safe: 0]?.id
        self.playerA2ID = roster.sideA[safe: 1]?.id
        self.playerB1ID = roster.sideB[safe: 0]?.id
        self.playerB2ID = roster.sideB[safe: 1]?.id
        self.teamAName = playerNames.teamAName
        self.teamBName = playerNames.teamBName
        self.averageHeartRate = averageHeartRate
        self.activeEnergyKilocalories = activeEnergyKilocalories
        self.distanceMeters = distanceMeters
        self.setRostersData = (try? JSONEncoder().encode(setRosters)) ?? Data()
        self.points = points
    }

    public var roster: MatchRoster {
        get {
            MatchRoster(
                playerA1ID: playerA1ID, playerA1Name: playerA1Name,
                playerA2ID: playerA2ID, playerA2Name: playerA2Name,
                playerB1ID: playerB1ID, playerB1Name: playerB1Name,
                playerB2ID: playerB2ID, playerB2Name: playerB2Name
            )
        }
        set {
            playerA1ID = newValue.sideA[safe: 0]?.id
            playerA1Name = newValue.sideA[safe: 0]?.name
            playerA2ID = newValue.sideA[safe: 1]?.id
            playerA2Name = newValue.sideA[safe: 1]?.name
            playerB1ID = newValue.sideB[safe: 0]?.id
            playerB1Name = newValue.sideB[safe: 0]?.name
            playerB2ID = newValue.sideB[safe: 1]?.id
            playerB2Name = newValue.sideB[safe: 1]?.name
        }
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

    /// Court lineup per set (index = set number). Empty for matches recorded
    /// without per-set side tracking.
    public var setRosters: [MatchRoster] {
        get {
            (try? JSONDecoder().decode([MatchRoster].self, from: setRostersData)) ?? []
        }
        set {
            setRostersData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    public var winner: Team? {
        get { winnerRawValue.flatMap(Team.init(rawValue:)) }
        set { winnerRawValue = newValue?.rawValue }
    }

    /// The match winner, falling back to whoever won more completed sets when the
    /// match ended early without a formally decided winner. `nil` only when the
    /// completed sets are level (a genuine tie) or none were finished.
    public var resolvedWinner: Team? {
        if let winner { return winner }
        let sets = completedSets
        let setsA = sets.filter { $0.winner == .a }.count
        let setsB = sets.filter { $0.winner == .b }.count
        if setsA > setsB { return .a }
        if setsB > setsA { return .b }
        return nil
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

    /// Games of a set that was started but never finished (e.g. the match was
    /// stopped early on court). `nil` for matches that reached a decided result.
    public var inProgressSetSummary: String? {
        guard winner == nil else { return nil }
        let state = replayedState()
        guard !state.isMatchOver else { return nil }
        guard state.isTieBreak || state.gamesA > 0 || state.gamesB > 0 else { return nil }
        return ScoreFormatter.currentSetGames(in: state)
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
            isCompleted: isCompleted,
            roster: roster,
            setRosters: setRosters
        )
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
