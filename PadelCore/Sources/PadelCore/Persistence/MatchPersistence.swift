import Foundation
import SwiftData

public enum MatchPersistence {
    @MainActor
    public static func saveCompletedMatch(
        context: ModelContext,
        rules: MatchRules,
        events: [PointEvent],
        startedAt: Date,
        teamAName: String?,
        teamBName: String?
    ) -> Match {
        let state = ScoringEngine.replay(events: events, rules: rules)
        let match = Match(
            startedAt: startedAt,
            endedAt: .now,
            rules: rules,
            completedSets: state.completedSets,
            winner: state.winner,
            teamAName: teamAName?.nilIfEmpty,
            teamBName: teamBName?.nilIfEmpty
        )
        context.insert(match)

        for (index, event) in events.enumerated() {
            let point = StoredPointEvent(
                sequence: index,
                team: event.team,
                timestamp: startedAt.addingTimeInterval(Double(index) * 20),
                match: match
            )
            context.insert(point)
            match.points.append(point)
        }

        try? context.save()
        return match
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
