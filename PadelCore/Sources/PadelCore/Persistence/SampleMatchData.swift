import Foundation
import SwiftData

public enum SampleMatchData {
    @MainActor
    public static func seed(into context: ModelContext) {
        guard (try? context.fetchCount(FetchDescriptor<Match>())) == 0 else { return }

        let samples: [(Date, TimeInterval, [Team], MatchRules, MatchPlayerSetup)] = [
            (
                Calendar.current.date(byAdding: .day, value: -1, to: .now)!,
                58 * 60,
                sampleEventsAWin(),
                .default,
                MatchPlayerSetup(
                    sideAPlayer1: .init(name: String(localized: "Alex")),
                    sideAPlayer2: .init(name: String(localized: "Maria")),
                    sideBPlayer1: .init(name: String(localized: "Chris")),
                    sideBPlayer2: .init(name: String(localized: "Dana"))
                )
            ),
            (
                Calendar.current.date(byAdding: .day, value: -4, to: .now)!,
                72 * 60,
                sampleEventsBWin(),
                MatchRules(setsToWin: 2, gamePointStyle: .advantage),
                MatchPlayerSetup(
                    sideAPlayer1: .init(name: String(localized: "Alex")),
                    sideAPlayer2: .init(name: String(localized: "Maria")),
                    sideBPlayer1: .init(name: String(localized: "Chris")),
                    sideBPlayer2: .init(name: String(localized: "Dana"))
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

        for (start, duration, events, rules, setup) in samples {
            let roster = PlayerPersistence.resolveRoster(context: context, setup: setup)
            let match = Match(
                startedAt: start,
                rules: rules,
                playerNames: setup.playerNames,
                roster: roster
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
            if setup.sideAPlayer1.trimmedName == String(localized: "Alex") {
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
