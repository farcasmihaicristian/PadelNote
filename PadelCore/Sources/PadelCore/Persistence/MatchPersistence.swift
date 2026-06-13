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

    @MainActor
    public static func saveTransferredMatch(
        context: ModelContext,
        payload: MatchTransferPayload
    ) -> Match? {
        let payloadID = payload.id
        var descriptor = FetchDescriptor<Match>(
            predicate: #Predicate { $0.id == payloadID }
        )
        descriptor.fetchLimit = 1
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }

        let state = ScoringEngine.replay(events: payload.events, rules: payload.rules)
        let match = Match(
            id: payload.id,
            startedAt: payload.startedAt,
            endedAt: payload.endedAt,
            rules: payload.rules,
            completedSets: state.completedSets,
            winner: state.winner,
            teamAName: payload.teamAName,
            teamBName: payload.teamBName
        )
        context.insert(match)

        for (index, event) in payload.events.enumerated() {
            let point = StoredPointEvent(
                sequence: index,
                team: event.team,
                timestamp: payload.startedAt.addingTimeInterval(Double(index) * 20),
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
