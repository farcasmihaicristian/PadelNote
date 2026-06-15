import Foundation
import SwiftData
import Testing
@testable import PadelCore

@Test @MainActor func saveCompletedMatchLinksPlayersInRoster() throws {
    let container = try makeContainer()
    let context = container.mainContext

    let rules = MatchRules(setsToWin: 1, gamePointStyle: .goldenPoint)
    let events: [PointEvent] = (0..<6).flatMap { _ in
        [PointEvent(team: .a), PointEvent(team: .a), PointEvent(team: .a), PointEvent(team: .a)]
    }

    let setup = MatchPlayerSetup(
        sideAPlayer1: .init(name: "Alex"),
        sideAPlayer2: .init(name: "Maria"),
        sideBPlayer1: .init(name: "Chris"),
        sideBPlayer2: .init(name: "Dana")
    )

    let match = MatchPersistence.saveCompletedMatch(
        context: context,
        rules: rules,
        events: events,
        startedAt: .now,
        playerSetup: setup
    )

    #expect(match.isCompleted)
    #expect(match.playerA1Name == "Alex")
    #expect(match.playerA2Name == "Maria")
    #expect(match.playerB1Name == "Chris")
    #expect(match.playerB2Name == "Dana")
    #expect(match.playerA1ID != nil)
    #expect(match.playerA2ID != nil)
    #expect(match.playerB1ID != nil)
    #expect(match.playerB2ID != nil)

    let players = try context.fetch(FetchDescriptor<Player>())
    #expect(players.count == 4)
    #expect(Set(players.map(\.displayName)) == Set(["Alex", "Maria", "Chris", "Dana"]))
}

@Test @MainActor func resolveRosterReusesExistingPlayerByName() throws {
    let container = try makeContainer()
    let context = container.mainContext

    let existing = Player(displayName: "Alex", normalizedName: "alex")
    context.insert(existing)
    try context.save()

    let roster = PlayerPersistence.resolveRoster(
        context: context,
        setup: MatchPlayerSetup(
            sideAPlayer1: .init(name: "alex"),
            sideAPlayer2: .init(name: "Maria"),
            sideBPlayer1: .init(name: "Chris"),
            sideBPlayer2: .init(name: "Dana")
        )
    )

    #expect(roster.sideA[safe: 0]?.id == existing.id)
    #expect(try context.fetch(FetchDescriptor<Player>()).count == 4)
}

@Test @MainActor func knownNamesFromMatchHistoryEmptyWhenNoCompletedMatches() throws {
    let container = try makeContainer()
    let context = container.mainContext

    let orphan = Player(displayName: "Orphan", normalizedName: "orphan")
    context.insert(orphan)
    try context.save()

    #expect(PlayerPersistence.knownNamesFromMatchHistory(context: context).isEmpty)
    #expect(PlayerPersistence.distinctDisplayNames(context: context).isEmpty)
}

@Test @MainActor func knownNamesFromMatchHistoryUsesCompletedMatchRosterOnly() throws {
    let container = try makeContainer()
    let context = container.mainContext

    let orphan = Player(displayName: "Orphan", normalizedName: "orphan")
    context.insert(orphan)
    try context.save()

    let rules = MatchRules(setsToWin: 1, gamePointStyle: .goldenPoint)
    let events: [PointEvent] = (0..<4).flatMap { _ in
        [PointEvent(team: .a), PointEvent(team: .a), PointEvent(team: .a), PointEvent(team: .a)]
    }

    _ = MatchPersistence.saveCompletedMatch(
        context: context,
        rules: rules,
        events: events,
        startedAt: .now,
        playerSetup: MatchPlayerSetup(
            sideAPlayer1: .init(name: "Alex"),
            sideAPlayer2: .init(name: "Maria"),
            sideBPlayer1: .init(name: "Chris"),
            sideBPlayer2: .init(name: "Dana")
        )
    )

    let names = Set(PlayerPersistence.knownNamesFromMatchHistory(context: context))
    #expect(names == Set(["Alex", "Maria", "Chris", "Dana"]))
    #expect(!names.contains("Orphan"))
}

@Test @MainActor func pruneUnreferencedPlayersRemovesOrphansButKeepsMe() throws {
    let container = try makeContainer()
    let context = container.mainContext

    let orphan = Player(displayName: "Orphan", normalizedName: "orphan")
    let me = Player(displayName: "Me", normalizedName: "me", isOwnedByCurrentUser: true)
    context.insert(orphan)
    context.insert(me)
    try context.save()

    PlayerPersistence.pruneUnreferencedPlayers(context: context)

    let remaining = try context.fetch(FetchDescriptor<Player>())
    #expect(remaining.count == 1)
    #expect(remaining.first?.displayName == "Me")
}

@Test func partnerStatsAggregateSideWinRate() {
    let alexID = UUID()
    let mariaID = UUID()
    let chrisID = UUID()
    let danaID = UUID()

    let rules = MatchRules(setsToWin: 1, gamePointStyle: .goldenPoint)
    let winEvents: [PointEvent] = (0..<4).flatMap { _ in
        [PointEvent(team: .a), PointEvent(team: .a), PointEvent(team: .a), PointEvent(team: .a)]
    }
    let lossEvents: [PointEvent] = (0..<4).flatMap { _ in
        [PointEvent(team: .b), PointEvent(team: .b), PointEvent(team: .b), PointEvent(team: .b)]
    }

    let roster = MatchRoster(
        playerA1ID: alexID, playerA1Name: "Alex",
        playerA2ID: mariaID, playerA2Name: "Maria",
        playerB1ID: chrisID, playerB1Name: "Chris",
        playerB2ID: danaID, playerB2Name: "Dana"
    )

    let summaries = [
        MatchSummary(
            rules: rules,
            events: winEvents,
            winner: .a,
            duration: 3600,
            isCompleted: true,
            roster: roster
        ),
        MatchSummary(
            rules: rules,
            events: lossEvents,
            winner: .b,
            duration: 3600,
            isCompleted: true,
            roster: roster
        ),
    ]

    let names = [
        alexID: "Alex",
        mariaID: "Maria",
        chrisID: "Chris",
        danaID: "Dana",
    ]

    let alexPartners = MatchStatistics.partnerStats(for: alexID, in: summaries, displayNames: names)
    let mariaPartner = alexPartners.first(where: { $0.id == mariaID })

    #expect(alexPartners.count == 1)
    #expect(mariaPartner?.matchCount == 2)
    #expect(mariaPartner?.wins == 1)
    #expect(mariaPartner?.losses == 1)
    #expect(mariaPartner?.winRate == 0.5)
}

@Test @MainActor func saveTransferredMatchIsIdempotentByID() throws {
    let container = try makeContainer()
    let context = container.mainContext

    let matchID = UUID()
    let events: [PointEvent] = (0..<6).flatMap { _ in
        [PointEvent(team: .a), PointEvent(team: .a), PointEvent(team: .a), PointEvent(team: .a)]
    }
    let payload = MatchTransferPayload(
        id: matchID,
        startedAt: .now,
        endedAt: .now,
        rules: MatchRules(setsToWin: 1, gamePointStyle: .goldenPoint),
        events: events,
        playerNames: MatchPlayerNames(
            playerA1: "Alex",
            playerA2: "Maria",
            playerB1: "Chris",
            playerB2: "Dana"
        )
    )

    _ = MatchPersistence.saveTransferredMatch(context: context, payload: payload)
    _ = MatchPersistence.saveTransferredMatch(context: context, payload: payload)

    let matches = try context.fetch(FetchDescriptor<Match>())
    #expect(matches.count == 1)
    #expect(matches.first?.winner == .a)

    let points = try context.fetch(FetchDescriptor<StoredPointEvent>())
    #expect(points.count == events.count)
}

@MainActor
private func makeContainer() throws -> ModelContainer {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(
        for: Match.self, StoredPointEvent.self, Player.self, AppUser.self,
        configurations: configuration
    )
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
