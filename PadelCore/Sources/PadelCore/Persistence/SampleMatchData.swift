import Foundation
import SwiftData

public enum SampleMatchData {
    public static func seed(into context: ModelContext) {
        guard (try? context.fetchCount(FetchDescriptor<Match>())) == 0 else { return }

        let samples: [(Date, TimeInterval, [Team], MatchRules, MatchPlayerNames)] = [
            (
                Calendar.current.date(byAdding: .day, value: -1, to: .now)!,
                58 * 60,
                sampleEventsAWin(),
                .default,
                MatchPlayerNames(
                    playerA1: String(localized: "Alex"),
                    playerA2: String(localized: "Maria"),
                    playerB1: String(localized: "Chris"),
                    playerB2: String(localized: "Dana")
                )
            ),
            (
                Calendar.current.date(byAdding: .day, value: -4, to: .now)!,
                72 * 60,
                sampleEventsBWin(),
                MatchRules(setsToWin: 2, gamePointStyle: .advantage),
                MatchPlayerNames(
                    teamAName: String(localized: "Team A"),
                    teamBName: String(localized: "Team B")
                )
            ),
            (
                Calendar.current.date(byAdding: .month, value: -1, to: .now)!,
                65 * 60,
                sampleEventsAWinShort(),
                MatchRules(setsToWin: 1, gamePointStyle: .goldenPoint),
                .empty
            ),
        ]

        for (start, duration, events, rules, playerNames) in samples {
            let match = Match(
                startedAt: start,
                rules: rules,
                playerNames: playerNames
            )
            context.insert(match)

            for (index, team) in events.enumerated() {
                let point = StoredPointEvent(
                    sequence: index,
                    team: team,
                    timestamp: start.addingTimeInterval(Double(index) * 25),
                    match: match
                )
                context.insert(point)
                match.points.append(point)
            }

            let state = ScoringEngine.replay(events: events.map { PointEvent(team: $0) }, rules: rules)
            match.completedSets = state.completedSets
            match.winner = state.winner
            match.endedAt = start.addingTimeInterval(duration)
            if playerNames.playerA1Name == String(localized: "Alex") {
                match.averageHeartRate = 142
                match.activeEnergyKilocalories = 620
                match.distanceMeters = 2800
            }
        }

        try? context.save()
    }

    private static func sampleEventsAWin() -> [Team] {
        var events: [Team] = []
        for _ in 0..<6 { events += [.a, .a, .a, .a] }
        for _ in 0..<4 { events += [.b, .b, .b, .b] }
        for _ in 0..<6 { events += [.a, .a, .a, .a] }
        return events
    }

    private static func sampleEventsBWin() -> [Team] {
        var events: [Team] = []
        for _ in 0..<6 { events += [.a, .a, .a, .a] }
        for _ in 0..<6 { events += [.b, .b, .b, .b] }
        for _ in 0..<4 { events += [.a, .a, .a, .a] }
        for _ in 0..<6 { events += [.b, .b, .b, .b] }
        return events
    }

    private static func sampleEventsAWinShort() -> [Team] {
        var events: [Team] = []
        for _ in 0..<6 { events += [.a, .a, .a, .a] }
        return events
    }
}
