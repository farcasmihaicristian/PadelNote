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
