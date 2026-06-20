import Foundation
import SwiftData

public enum MatchPersistence {
    @MainActor
    public static func saveCompletedMatch(
        context: ModelContext,
        rules: MatchRules,
        events: [PointEvent],
        startedAt: Date,
        playerSetup: MatchPlayerSetup
    ) -> Match {
        let state = ScoringEngine.replay(events: events, rules: rules)
        let roster = PlayerPersistence.resolveRoster(context: context, setup: playerSetup)
        let match = Match(
            startedAt: startedAt,
            endedAt: .now,
            rules: rules,
            completedSets: state.completedSets,
            winner: state.winner,
            playerNames: playerSetup.playerNames,
            roster: roster
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

        let state = ScoringEngine.replay(events: payload.events, rules: payload.rules)
        let setup = MatchPlayerSetup(
            sideAPlayer1: .init(name: payload.playerNames.playerA1Name ?? "", playerID: nil),
            sideAPlayer2: .init(name: payload.playerNames.playerA2Name ?? "", playerID: nil),
            sideBPlayer1: .init(name: payload.playerNames.playerB1Name ?? "", playerID: nil),
            sideBPlayer2: .init(name: payload.playerNames.playerB2Name ?? "", playerID: nil)
        )
        let roster = PlayerPersistence.resolveRoster(context: context, setup: setup)
        let setRosters = payload.setLineups.map { lineup in
            PlayerPersistence.resolveRoster(
                context: context,
                setup: MatchPlayerSetup(
                    sideAPlayer1: .init(name: lineup.playerA1Name ?? "", playerID: nil),
                    sideAPlayer2: .init(name: lineup.playerA2Name ?? "", playerID: nil),
                    sideBPlayer1: .init(name: lineup.playerB1Name ?? "", playerID: nil),
                    sideBPlayer2: .init(name: lineup.playerB2Name ?? "", playerID: nil)
                )
            )
        }
        let match: Match

        if let existing = try? context.fetch(descriptor).first {
            match = existing
            replacePoints(on: match, from: payload, context: context)
        } else {
            match = Match(
                id: payload.id,
                startedAt: payload.startedAt,
                endedAt: payload.endedAt,
                rules: payload.rules,
                completedSets: state.completedSets,
                winner: state.winner,
                playerNames: payload.playerNames,
                roster: roster,
                averageHeartRate: payload.averageHeartRate,
                activeEnergyKilocalories: payload.activeEnergyKilocalories,
                distanceMeters: payload.distanceMeters,
                setRosters: setRosters
            )
            context.insert(match)
            appendPoints(to: match, from: payload, context: context)
        }

        match.startedAt = payload.startedAt
        match.endedAt = payload.endedAt
        match.rules = payload.rules
        match.completedSets = state.completedSets
        match.winner = state.winner
        match.playerNames = payload.playerNames
        match.roster = roster
        match.setRosters = setRosters
        match.averageHeartRate = payload.averageHeartRate
        match.activeEnergyKilocalories = payload.activeEnergyKilocalories
        match.distanceMeters = payload.distanceMeters

        do {
            try context.save()
            return match
        } catch {
            assertionFailure("Failed to save transferred match: \(error)")
            return nil
        }
    }

    @MainActor
    private static func replacePoints(
        on match: Match,
        from payload: MatchTransferPayload,
        context: ModelContext
    ) {
        for point in match.points {
            context.delete(point)
        }
        match.points.removeAll()
        appendPoints(to: match, from: payload, context: context)
    }

    @MainActor
    private static func appendPoints(
        to match: Match,
        from payload: MatchTransferPayload,
        context: ModelContext
    ) {
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
    }
}
