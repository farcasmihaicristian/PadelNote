import Foundation
import SwiftData
import Testing
@testable import PadelCore

// MARK: - P0-1 — live-score serve fields survive the codec

@Test func liveScoreCodecPreservesServeFields() {
    let state = ScoringEngine.replay(events: [PointEvent(team: .a)], rules: .default)
    let serve = ServeContext(
        servingTeam: .b,
        servingSlot: .sideBPlayer1,
        side: .left,
        isTieBreak: false,
        isDecidingPoint: false
    )
    let snapshot = LiveScoreSnapshot(
        matchID: UUID(),
        state: state,
        playerNames: MatchPlayerNames(playerA1: "A", playerA2: "B", playerB1: "C", playerB2: "D"),
        pointCount: 1,
        serve: serve,
        servingPlayerName: "C"
    )

    let encoded = SyncPayloadCodec.encodeLiveScore(snapshot)
    let decoded = SyncPayloadCodec.decodeLiveScore(from: encoded)

    #expect(decoded?.servingTeam == .b)
    #expect(decoded?.serveSide == .left)
    #expect(decoded?.servingPlayerName == "C")
}

// MARK: - P2-1 — serve-order alignment

@Test func serveOrderAlignmentDerivesTruncatesAndInherits() {
    // First set derives from firstServer.
    let one = ServeOrder.aligned([], completedSetCount: 0, firstServer: .sideBPlayer1)
    #expect(one.count == 1)
    #expect(one[0] == ServeOrder.standard(firstServer: .sideBPlayer1))

    // A new set inherits the previous set's order.
    let two = ServeOrder.aligned(one, completedSetCount: 1, firstServer: .sideBPlayer1)
    #expect(two.count == 2)
    #expect(two[1] == two[0])

    // Undoing back into an earlier set trims later orders.
    let trimmed = ServeOrder.aligned(two, completedSetCount: 0, firstServer: .sideBPlayer1)
    #expect(trimmed.count == 1)
    #expect(trimmed[0] == one[0])
}

// MARK: - P2-2 — single sudden-death / deuce source of truth

@Test func suddenDeathPointMatchesGamePointStyle() {
    func deuceState(_ style: GamePointStyle, deuceCount: Int = 1) -> MatchState {
        var state = MatchState(rules: MatchRules(gamePointStyle: style))
        state.pointA = 3
        state.pointB = 3
        state.deuceCount = deuceCount
        return state
    }

    let golden = deuceState(.goldenPoint)
    #expect(golden.isAtDeuce)
    #expect(golden.isSuddenDeathPoint)

    let advantage = deuceState(.advantage)
    #expect(advantage.isAtDeuce)
    #expect(!advantage.isSuddenDeathPoint)

    #expect(!deuceState(.starPoint, deuceCount: 1).isSuddenDeathPoint)
    #expect(deuceState(.starPoint, deuceCount: 3).isSuddenDeathPoint)

    // Not at deuce → never sudden death.
    var notDeuce = MatchState(rules: MatchRules(gamePointStyle: .goldenPoint))
    notDeuce.pointA = 3
    notDeuce.pointB = 2
    #expect(!notDeuce.isAtDeuce)
    #expect(!notDeuce.isSuddenDeathPoint)
}

// MARK: - P3-2 — payload schema versioning

@Test func matchTransferPayloadCarriesSchemaVersion() throws {
    let payload = MatchTransferPayload(startedAt: .now, endedAt: .now, rules: .default, events: [])
    let data = try JSONEncoder().encode(payload)
    let decoded = try JSONDecoder().decode(MatchTransferPayload.self, from: data)
    #expect(decoded.schemaVersion == MatchTransferPayload.currentSchemaVersion)
}

// MARK: - P0-4 — duplicate names resolve to one Player

@Test @MainActor func resolveRosterMergesRepeatedNameToSinglePlayer() throws {
    let container = try makeContainer()
    let context = container.mainContext

    let roster = PlayerPersistence.resolveRoster(
        context: context,
        setup: MatchPlayerSetup(
            sideAPlayer1: .init(name: "Sam"),
            sideAPlayer2: .init(name: "Maria"),
            sideBPlayer1: .init(name: "Sam"),
            sideBPlayer2: .init(name: "Dana")
        )
    )

    #expect(roster.sideA[safe: 0]?.id == roster.sideB[safe: 0]?.id)

    let sams = try context.fetch(FetchDescriptor<Player>()).filter { $0.normalizedName == "sam" }
    #expect(sams.count == 1)
}

// MARK: - P0-2 — a stale retransmit must not overwrite a newer record

@Test @MainActor func saveTransferredMatchIgnoresStaleRetransmit() throws {
    let container = try makeContainer()
    let context = container.mainContext

    func sixGames(_ team: Team) -> [PointEvent] {
        (0..<6).flatMap { _ in (0..<4).map { _ in PointEvent(team: team) } }
    }

    let id = UUID()
    let base = Date(timeIntervalSince1970: 1_000_000)
    let rules = MatchRules(setsToWin: 1, gamePointStyle: .goldenPoint)
    let names = MatchPlayerNames(playerA1: "Alex", playerA2: "Maria", playerB1: "Chris", playerB2: "Dana")

    let newer = MatchTransferPayload(
        id: id, startedAt: base, endedAt: base.addingTimeInterval(3600),
        rules: rules, events: sixGames(.a), playerNames: names
    )
    _ = MatchPersistence.saveTransferredMatch(context: context, payload: newer)

    // Older retransmit with a different result must be ignored.
    let older = MatchTransferPayload(
        id: id, startedAt: base, endedAt: base.addingTimeInterval(1800),
        rules: rules, events: sixGames(.b), playerNames: names
    )
    _ = MatchPersistence.saveTransferredMatch(context: context, payload: older)

    let matches = try context.fetch(FetchDescriptor<Match>())
    #expect(matches.count == 1)
    #expect(matches.first?.winner == .a)
}

// MARK: - P0-5 — name-only linking skips ambiguous namesakes

@Test @MainActor func linkablePastMatchCountIsZeroWhenNamesakeExists() throws {
    let container = try makeContainer()
    let context = container.mainContext

    let me = Player(displayName: "Alex", normalizedName: "alex", isOwnedByCurrentUser: true)
    let namesake = Player(displayName: "Alex", normalizedName: "alex")
    context.insert(me)
    context.insert(namesake)
    try context.save()

    #expect(UserAccountPersistence.linkablePastMatchCount(for: me, context: context) == 0)
    #expect(UserAccountPersistence.linkPastMatches(to: me, context: context) == 0)
}

// MARK: - P1-2 — cumulative score lines computed in one pass

@Test @MainActor func scoreLinesBySequenceCoversEveryPoint() throws {
    let container = try makeContainer()
    let context = container.mainContext

    let events: [PointEvent] = (0..<6).flatMap { _ in (0..<4).map { _ in PointEvent(team: .a) } }
    let match = try #require(MatchPersistence.saveCompletedMatch(
        context: context,
        rules: MatchRules(setsToWin: 1, gamePointStyle: .goldenPoint),
        events: events,
        startedAt: .now,
        playerSetup: MatchPlayerSetup(playerNames: MatchPlayerNames(
            playerA1: "Alex", playerA2: "Maria", playerB1: "Chris", playerB2: "Dana"
        ))
    ))

    let lines = match.scoreLinesBySequence()
    #expect(lines.count == events.count)
    // Matches the prefix-replay result it replaces.
    #expect(lines[0] == match.scoreLine(afterPointCount: 1))
    #expect(lines[events.count - 1] == match.scoreLine(afterPointCount: events.count))
}

// MARK: - P1-5 — stored completion flag for SwiftData predicates

@Test @MainActor func completionFlagBackfillMarksFinishedMatches() throws {
    let container = try makeContainer()
    let context = container.mainContext
    let match = Match(startedAt: .now, endedAt: .now)
    context.insert(match)
    match.points.append(StoredPointEvent(sequence: 0, team: .a, match: match))
    match.isComplete = false
    try context.save()

    MatchPersistence.backfillCompletionFlags(context: context)

    #expect(match.isComplete)
    #expect(match.isCompleted)
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
