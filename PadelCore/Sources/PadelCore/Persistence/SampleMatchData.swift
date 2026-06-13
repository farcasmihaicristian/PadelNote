import Foundation
import SwiftData

public enum SampleMatchData {
    public static func seed(into context: ModelContext) {
        guard (try? context.fetchCount(FetchDescriptor<Match>())) == 0 else { return }

        let samples: [(Date, TimeInterval, [Team], MatchRules, String?, String?)] = [
            (
                Calendar.current.date(byAdding: .day, value: -1, to: .now)!,
                58 * 60,
                sampleEventsAWin(),
                .default,
                String(localized: "Alex & Maria"),
                String(localized: "Chris & Dana")
            ),
            (
                Calendar.current.date(byAdding: .day, value: -4, to: .now)!,
                72 * 60,
                sampleEventsBWin(),
                MatchRules(setsToWin: 2, gamePointStyle: .advantage),
                String(localized: "Team A"),
                String(localized: "Team B")
            ),
            (
                Calendar.current.date(byAdding: .month, value: -1, to: .now)!,
                65 * 60,
                sampleEventsAWinShort(),
                MatchRules(setsToWin: 1, gamePointStyle: .goldenPoint),
                nil,
                nil
            ),
        ]

        for (start, duration, events, rules, teamA, teamB) in samples {
            let match = Match(
                startedAt: start,
                rules: rules,
                teamAName: teamA,
                teamBName: teamB
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
