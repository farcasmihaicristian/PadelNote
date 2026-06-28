import Foundation
import SwiftData

public enum MatchPersistence {
    @MainActor
    @discardableResult
    public static func saveCompletedMatch(
        context: ModelContext,
        rules: MatchRules,
        events: [PointEvent],
        startedAt: Date,
        playerSetup: MatchPlayerSetup,
        setServeOrders: [ServeOrder] = []
    ) -> Match? {
        let state = ScoringEngine.replay(events: events, rules: rules)
        let roster = PlayerPersistence.resolveRoster(context: context, setup: playerSetup)
        let match = Match(
            startedAt: startedAt,
            endedAt: .now,
            rules: rules,
            completedSets: state.completedSets,
            winner: state.winner,
            playerNames: playerSetup.playerNames,
            roster: roster,
            setServeOrders: setServeOrders
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

        do {
            try context.save()
            return match
        } catch {
            assertionFailure("Failed to save completed match: \(error)")
            return nil
        }
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
        let setup = MatchPlayerSetup(playerNames: payload.playerNames)
        // Share one player cache across the canonical roster and every per-set
        // lineup so a name that recurs across them resolves to a single Player.
        var playerCache: [String: Player] = [:]
        let roster = PlayerPersistence.resolveRoster(context: context, setup: setup, cache: &playerCache)
        let setRosters = payload.setLineups.map { lineup in
            PlayerPersistence.resolveRoster(
                context: context,
                setup: MatchPlayerSetup(playerNames: lineup),
                cache: &playerCache
            )
        }
        let match: Match

        if let existing = try? context.fetch(descriptor).first {
            // Ordering guard: a stale retransmit (older than what we already
            // stored) must not clobber the newer record.
            if let existingEnd = existing.endedAt, existingEnd > payload.endedAt {
                return existing
            }
            match = existing
            // Skip the costly delete/recreate of every point row when the stored
            // points already match the incoming payload exactly — the common case
            // when the watch re-flushes an already-synced match.
            if !storedEventsMatch(existing, payload.events) {
                replacePoints(on: match, from: payload, context: context)
            }
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
                setRosters: setRosters,
                setServeOrders: payload.setServeOrders
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
        match.setServeOrders = payload.setServeOrders
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

    /// True when the match's stored points already match the payload's events
    /// exactly (same count and per-position team), so no rebuild is needed.
    @MainActor
    private static func storedEventsMatch(_ match: Match, _ events: [PointEvent]) -> Bool {
        let stored = match.sortedPoints
        guard stored.count == events.count else { return false }
        for (index, event) in events.enumerated() where stored[index].team != event.team {
            return false
        }
        return true
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
