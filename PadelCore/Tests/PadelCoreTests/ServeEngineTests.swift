import Testing
@testable import PadelCore

// MARK: - Helpers

private func winGame(for team: Team) -> [Team] {
    switch team {
    case .a: [.a, .a, .a, .a]
    case .b: [.b, .b, .b, .b]
    }
}

private func reachGameScore(gamesA: Int, gamesB: Int) -> [Team] {
    var events: [Team] = []
    var a = 0
    var b = 0
    while a < gamesA || b < gamesB {
        if a < gamesA {
            events += winGame(for: .a)
            a += 1
        }
        if b < gamesB {
            events += winGame(for: .b)
            b += 1
        }
    }
    return events
}

private func timeline(_ teams: [Team], rules: MatchRules = .default, orders: [ServeOrder] = [.default]) -> ServeTimeline {
    ServeEngine.timeline(events: teams.map { PointEvent(team: $0) }, rules: rules, orders: orders)
}

// MARK: - Order model

@Test func serveOrderRotationFollowsTeamAlternation() {
    let order = ServeOrder.default
    #expect(order.rotation == [.sideAPlayer1, .sideBPlayer1, .sideAPlayer2, .sideBPlayer2])
    #expect(order.server(forGameInSet: 0) == .sideAPlayer1)
    #expect(order.server(forGameInSet: 1) == .sideBPlayer1)
    #expect(order.server(forGameInSet: 4) == .sideAPlayer1)
}

// MARK: - First serve

@Test func freshMatchServesFromRightWithFirstServer() {
    let upcoming = timeline([]).upcoming
    #expect(upcoming.servingSlot == .sideAPlayer1)
    #expect(upcoming.servingTeam == .a)
    #expect(upcoming.side == .right)
    #expect(!upcoming.isDecidingPoint)
}

@Test func serveSideAlternatesEachPointWithinGame() {
    #expect(timeline([.a]).upcoming.side == .left)
    #expect(timeline([.a, .b]).upcoming.side == .right)
    #expect(timeline([.a, .b, .a]).upcoming.side == .left)
    // Server unchanged within the game.
    #expect(timeline([.a, .b, .a]).upcoming.servingSlot == .sideAPlayer1)
}

// MARK: - Server rotation across games

@Test func serverRotatesAfterEachGame() {
    #expect(timeline(winGame(for: .a)).upcoming.servingSlot == .sideBPlayer1)

    var twoGames = winGame(for: .a)
    twoGames += winGame(for: .b)
    #expect(timeline(twoGames).upcoming.servingSlot == .sideAPlayer2)

    var threeGames = twoGames
    threeGames += winGame(for: .a)
    #expect(timeline(threeGames).upcoming.servingSlot == .sideBPlayer2)

    var fourGames = threeGames
    fourGames += winGame(for: .b)
    #expect(timeline(fourGames).upcoming.servingSlot == .sideAPlayer1)
    #expect(timeline(fourGames).upcoming.side == .right)
}

// MARK: - Points & games attribution

@Test func pointsRecordServerAndWinner() {
    let tl = timeline(winGame(for: .a))
    #expect(tl.points.count == 4)
    #expect(tl.points.allSatisfy { $0.servingSlot == .sideAPlayer1 })
    #expect(tl.points.allSatisfy { $0.winner == .a })
}

@Test func serviceGamesTrackHoldAndBreak() {
    var events = winGame(for: .a) // server A1 holds
    events += winGame(for: .a)    // server B1 broken (A wins B1's serve)
    let tl = timeline(events)
    #expect(tl.games.count == 2)
    #expect(tl.games[0].serverSlot == .sideAPlayer1)
    #expect(tl.games[0].winner == .a)
    #expect(tl.games[0].held)
    #expect(tl.games[1].serverSlot == .sideBPlayer1)
    #expect(tl.games[1].winner == .a)
    #expect(!tl.games[1].held)
}

// MARK: - Deciding point

@Test func goldenPointFlaggedAsDecidingAndHonorsOverride() {
    let rules = MatchRules(gamePointStyle: .goldenPoint)
    let deuce: [Team] = [.a, .a, .a, .b, .b, .b]
    let upcoming = timeline(deuce, rules: rules).upcoming
    #expect(upcoming.isDecidingPoint)

    let chosen = ServeEngine.currentServe(
        events: deuce.map { PointEvent(team: $0) },
        rules: rules,
        orders: [.default],
        decidingSideOverride: .left
    )
    #expect(chosen.side == .left)
    #expect(chosen.servingSlot == .sideAPlayer1)
}

@Test func advantageStyleHasNoDecidingPoint() {
    let rules = MatchRules(gamePointStyle: .advantage)
    let deuce: [Team] = [.a, .a, .a, .b, .b, .b]
    #expect(!timeline(deuce, rules: rules).upcoming.isDecidingPoint)
}

// MARK: - Tie-break

@Test func tieBreakServeRotationAndSides() {
    let base = reachGameScore(gamesA: 6, gamesB: 6)

    let start = timeline(base).upcoming
    #expect(start.isTieBreak)
    #expect(start.servingSlot == .sideAPlayer1)
    #expect(start.side == .right)

    #expect(timeline(base + [.a]).upcoming.servingSlot == .sideBPlayer1)
    #expect(timeline(base + [.a]).upcoming.side == .left)

    #expect(timeline(base + [.a, .b]).upcoming.servingSlot == .sideBPlayer1)
    #expect(timeline(base + [.a, .b]).upcoming.side == .right)

    #expect(timeline(base + [.a, .b, .a]).upcoming.servingSlot == .sideAPlayer2)
    #expect(timeline(base + [.a, .b, .a]).upcoming.side == .left)
}

// MARK: - Order fallback

@Test func emptyOrdersFallBackToDefault() {
    let upcoming = ServeEngine.timeline(events: [], rules: .default, orders: []).upcoming
    #expect(upcoming.servingSlot == .sideAPlayer1)
}

@Test func customFirstServerChangesRotation() {
    let order = ServeOrder.standard(firstServer: .sideBPlayer2)
    #expect(order.rotation == [.sideBPlayer2, .sideAPlayer1, .sideBPlayer1, .sideAPlayer2])
    let upcoming = ServeEngine.timeline(events: [], rules: .default, orders: [order]).upcoming
    #expect(upcoming.servingSlot == .sideBPlayer2)
    #expect(upcoming.servingTeam == .b)
}

// MARK: - FIP between-set handoff

@Test func nextSetOpensWithFIPContinuationAfterSixFour() {
    // Default A1→B1→A2→B2. After 10 games (6-4), next is A2 (team A again).
    let set1 = ServeOrder.default
    let set2 = set1.orderStartingNextSet(afterGamesPlayed: 10)
    #expect(set2.firstServer == .sideAPlayer2)
    #expect(set2.rotation == [.sideAPlayer2, .sideBPlayer2, .sideAPlayer1, .sideBPlayer1])

    let events = reachGameScore(gamesA: 6, gamesB: 4)
    let orders = ServeOrder.aligned([set1], completedSets: [SetScore(gamesA: 6, gamesB: 4)], firstServer: .sideAPlayer1)
    let upcoming = timeline(events, orders: orders).upcoming
    #expect(upcoming.servingSlot == .sideAPlayer2)
    #expect(upcoming.servingTeam == .a)
    #expect(!upcoming.isTieBreak)
}

@Test func nextSetOpensWithOtherTeamAfterSixThree() {
    // 9 games with A1→B1→A2→B2: last server A1, next B1 (other team).
    let set1 = ServeOrder.default
    let set2 = set1.orderStartingNextSet(afterGamesPlayed: 9)
    #expect(set2.firstServer == .sideBPlayer1)

    let events = reachGameScore(gamesA: 6, gamesB: 3)
    let orders = ServeOrder.aligned(
        [set1],
        completedSets: [SetScore(gamesA: 6, gamesB: 3)],
        firstServer: .sideAPlayer1
    )
    #expect(timeline(events, orders: orders).upcoming.servingSlot == .sideBPlayer1)
}

@Test func nextSetAfterTieBreakStartsWithPairThatDidNotOpenTieBreak() {
    // At 6-6, TB opens with A1. FIP: next set opened by the other pair → B.
    // 7+6 = 13 games in the SetScore → server(13) = B1.
    let set1 = ServeOrder.default
    #expect(set1.server(forGameInSet: 12) == .sideAPlayer1)
    let set2 = set1.orderStartingNextSet(afterGamesPlayed: 13)
    #expect(set2.firstServer == .sideBPlayer1)
    #expect(set2.firstServer.team == .b)

    var events = reachGameScore(gamesA: 6, gamesB: 6)
    // Win TB 7-0 for A.
    events += Array(repeating: Team.a, count: 7)
    let finished = ScoringEngine.replay(
        events: events.map { PointEvent(team: $0) },
        rules: .default
    )
    #expect(finished.completedSets.count == 1)
    #expect(finished.completedSets[0].gamesA == 7 && finished.completedSets[0].gamesB == 6)

    let orders = ServeOrder.aligned(
        [set1],
        completedSets: finished.completedSets,
        firstServer: .sideAPlayer1
    )
    #expect(timeline(events, orders: orders).upcoming.servingSlot == .sideBPlayer1)
}
