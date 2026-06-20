import Testing
@testable import PadelCore

// MARK: - Helpers

private func matchState(
    rules: MatchRules = MatchRules(),
    events: [Team] = []
) -> MatchState {
    ScoringEngine.replay(
        events: events.map { PointEvent(team: $0) },
        rules: rules
    )
}

private func winGame(for team: Team) -> [Team] {
    switch team {
    case .a: [.a, .a, .a, .a]
    case .b: [.b, .b, .b, .b]
    }
}

private func tieBreakPoints(pointsA: Int, pointsB: Int) -> [Team] {
    var events: [Team] = []
    var a = 0
    var b = 0
    while a < pointsA || b < pointsB {
        if a < pointsA {
            events.append(.a)
            a += 1
        }
        if b < pointsB {
            events.append(.b)
            b += 1
        }
    }
    return events
}

private func winSet(for team: Team, games: Int = 6) -> [Team] {
    (0..<games).flatMap { _ in winGame(for: team) }
}

/// Builds point events to reach a specific game score within the current set.
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

// MARK: - Basic game scoring

@Test func freshMatchStartsAtLoveAll() {
    let s = MatchState(rules: .default)
    #expect(s.pointA == 0 && s.pointB == 0)
    #expect(s.gamesA == 0 && s.gamesB == 0)
    #expect(!s.isMatchOver)
}

@Test func teamAWinsGameFromLove() {
    let s = matchState(events: [.a, .a, .a, .a])
    #expect(s.gamesA == 1 && s.gamesB == 0)
    #expect(s.pointA == 0 && s.pointB == 0)
}

@Test func teamBWinsGameFromLove() {
    let s = matchState(events: [.b, .b, .b, .b])
    #expect(s.gamesB == 1 && s.gamesA == 0)
}

@Test func gameWonAtFortyThirty() {
    let s = matchState(events: [.a, .a, .a, .b, .b, .a])
    #expect(s.gamesA == 1)
    #expect(ScoreFormatter.currentGameScore(in: s) == "0-0")
}

@Test func pointsProgressThrough153040() {
    var s = MatchState(rules: MatchRules(gamePointStyle: .advantage))
    s = ScoringEngine.apply(point: .a, to: s)
    #expect(ScoreFormatter.gamePoints(for: .a, in: s) == "15")
    s = ScoringEngine.apply(point: .a, to: s)
    #expect(ScoreFormatter.gamePoints(for: .a, in: s) == "30")
    s = ScoringEngine.apply(point: .a, to: s)
    #expect(ScoreFormatter.gamePoints(for: .a, in: s) == "40")
}

// MARK: - Deuce & advantage

@Test func deuceReachedAtFortyForty() {
    let s = matchState(
        rules: MatchRules(gamePointStyle: .advantage),
        events: [.a, .a, .b, .b, .a, .b]
    )
    #expect(s.pointA == 3 && s.pointB == 3)
    #expect(s.advantageTeam == nil)
}

@Test func advantageThenGameWon() {
    let s = matchState(
        rules: MatchRules(gamePointStyle: .advantage),
        events: [.a, .a, .b, .b, .a, .b, .a, .a]
    )
    #expect(s.gamesA == 1)
}

@Test func advantageLostReturnsToDeuce() {
    let s = matchState(
        rules: MatchRules(gamePointStyle: .advantage),
        events: [.a, .a, .b, .b, .a, .b, .a, .b]
    )
    #expect(s.pointA == 3 && s.pointB == 3)
    #expect(s.advantageTeam == nil)
    #expect(s.deuceCount == 2)
}

// MARK: - Golden point

@Test func goldenPointDeuceShowsGP() {
    let s = matchState(
        rules: MatchRules(gamePointStyle: .goldenPoint),
        events: [.a, .a, .b, .b, .a, .b]
    )
    #expect(ScoreFormatter.currentGameScore(in: s) == "GP-GP")
}

@Test func goldenPointWinsGameAtDeuce() {
    let s = matchState(
        rules: MatchRules(gamePointStyle: .goldenPoint),
        events: [.a, .a, .b, .b, .a, .b, .a]
    )
    #expect(s.gamesA == 1)
}

@Test func goldenPointEitherTeamCanWin() {
    let s = matchState(
        rules: MatchRules(gamePointStyle: .goldenPoint),
        events: [.a, .a, .b, .b, .a, .b, .b]
    )
    #expect(s.gamesB == 1)
}

// MARK: - Star point

@Test func starPointUsesAdvantageForFirstTwoDeuces() {
    let events: [Team] = [.a, .a, .b, .b, .a, .b, .a, .b, .a, .b]
    let s = matchState(rules: MatchRules(gamePointStyle: .starPoint), events: events)
    #expect(s.pointA == 3 && s.pointB == 3)
    #expect(s.deuceCount == 3)
    #expect(s.advantageTeam == nil)
}

@Test func starPointSuddenDeathOnThirdDeuce() {
    let events: [Team] = [.a, .a, .b, .b, .a, .b, .a, .b, .a, .b, .a]
    let s = matchState(rules: MatchRules(gamePointStyle: .starPoint), events: events)
    #expect(s.gamesA == 1)
}

@Test func starPointFirstAdvantageShowsAd() {
    // 40-40 then A takes the first advantage.
    let s = matchState(rules: MatchRules(gamePointStyle: .starPoint), events: [.a, .a, .b, .b, .a, .b, .a])
    #expect(ScoreFormatter.gamePoints(for: .a, in: s) == "Ad")
    #expect(ScoreFormatter.gamePoints(for: .b, in: s) == "40")
}

@Test func starPointSecondAdvantageShowsAd2() {
    // First advantage to A is lost, second advantage taken by A.
    let s = matchState(
        rules: MatchRules(gamePointStyle: .starPoint),
        events: [.a, .a, .b, .b, .a, .b, .a, .b, .a]
    )
    #expect(s.deuceCount == 2)
    #expect(ScoreFormatter.gamePoints(for: .a, in: s) == "Ad2")
    #expect(ScoreFormatter.gamePoints(for: .b, in: s) == "40")
}

@Test func starPointThirdDeuceShowsSuddenDeath() {
    // Both advantages lost -> third deuce is sudden death.
    let s = matchState(
        rules: MatchRules(gamePointStyle: .starPoint),
        events: [.a, .a, .b, .b, .a, .b, .a, .b, .a, .b]
    )
    #expect(s.deuceCount == 3)
    #expect(s.advantageTeam == nil)
    #expect(ScoreFormatter.currentGameScore(in: s) == "SP-SP")
}

@Test func advantageStyleNeverShowsAd2OrSuddenDeath() {
    // Classic advantage: repeated deuces still just show "Ad".
    let s = matchState(
        rules: MatchRules(gamePointStyle: .advantage),
        events: [.a, .a, .b, .b, .a, .b, .a, .b, .a]
    )
    #expect(ScoreFormatter.gamePoints(for: .a, in: s) == "Ad")
}

// MARK: - Sets

@Test func setWonAtSixFour() {
    let s = matchState(
        rules: MatchRules(gamePointStyle: .goldenPoint),
        events: winSet(for: .a, games: 6)
    )
    #expect(s.completedSets.count == 1)
    #expect(s.completedSets[0].gamesA == 6 && s.completedSets[0].gamesB == 0)
}

@Test func setWonAtSevenFive() {
    var events = reachGameScore(gamesA: 5, gamesB: 5)
    events += winGame(for: .a)
    events += winGame(for: .a)
    let s = matchState(rules: MatchRules(gamePointStyle: .goldenPoint), events: events)
    #expect(s.completedSets.count == 1)
    #expect(s.completedSets[0].gamesA == 7 && s.completedSets[0].gamesB == 5)
}

@Test func setNotWonAtSixFive() {
    var events = reachGameScore(gamesA: 5, gamesB: 5)
    events += winGame(for: .a)
    let s = matchState(rules: MatchRules(gamePointStyle: .goldenPoint), events: events)
    #expect(s.completedSets.isEmpty)
    #expect(s.gamesA == 6 && s.gamesB == 5)
}

// MARK: - Tie-break

@Test func classicTieBreakStartsAtSixAll() {
    let s = matchState(
        rules: MatchRules(gamePointStyle: .goldenPoint),
        events: reachGameScore(gamesA: 6, gamesB: 6)
    )
    #expect(s.isTieBreak)
    #expect(s.tieBreakPointsA == 0 && s.tieBreakPointsB == 0)
}

@Test func classicTieBreakWonSevenFive() {
    var events = reachGameScore(gamesA: 6, gamesB: 6)
    events += tieBreakPoints(pointsA: 7, pointsB: 5)
    let s = matchState(rules: MatchRules(gamePointStyle: .goldenPoint), events: events)
    #expect(s.completedSets.count == 1)
    #expect(s.completedSets[0].gamesA == 7 && s.completedSets[0].gamesB == 6)
    #expect(s.completedSets[0].tieBreakA == 7)
    #expect(s.completedSets[0].tieBreakB == 5)
}

@Test func tieBreakMustWinByTwo() {
    var events = reachGameScore(gamesA: 6, gamesB: 6)
    events += tieBreakPoints(pointsA: 6, pointsB: 6)
    let s = matchState(rules: MatchRules(gamePointStyle: .goldenPoint), events: events)
    #expect(s.isTieBreak)
    #expect(s.tieBreakPointsA == 6 && s.tieBreakPointsB == 6)
}

@Test func superTieBreakInDecidingSet() {
    let rules = MatchRules(
        gamePointStyle: .goldenPoint,
        setTieBreak: .classic,
        finalSetTieBreak: .superTieBreak10
    )
    var events = winSet(for: .a, games: 6)
    events += winSet(for: .b, games: 6)
    events += reachGameScore(gamesA: 6, gamesB: 6)
    let s = matchState(rules: rules, events: events)
    #expect(s.isTieBreak)
    #expect(s.isDecidingSet)

    var finished = s
    for _ in 0..<10 { finished = ScoringEngine.apply(point: .a, to: finished) }
    for _ in 0..<8 { finished = ScoringEngine.apply(point: .b, to: finished) }
    #expect(finished.completedSets.count == 3)
    #expect(finished.completedSets[2].tieBreakA == 10)
}

@Test func noTieBreakWhenStyleIsNone() {
    let rules = MatchRules(gamePointStyle: .goldenPoint, setTieBreak: .none)
    let s = matchState(rules: rules, events: reachGameScore(gamesA: 6, gamesB: 6))
    #expect(!s.isTieBreak)
    #expect(s.gamesA == 6 && s.gamesB == 6)
}

// MARK: - Match

@Test func matchWonBestOfThree() {
    let rules = MatchRules(setsToWin: 2, gamePointStyle: .goldenPoint)
    var events = winSet(for: .a, games: 6)
    events += winSet(for: .b, games: 6)
    events += winSet(for: .a, games: 6)
    let s = matchState(rules: rules, events: events)
    #expect(s.isMatchOver)
    #expect(s.winner == .a)
    #expect(s.setsWonA == 2)
}

@Test func matchNotOverAtOneSetAll() {
    let rules = MatchRules(setsToWin: 2, gamePointStyle: .goldenPoint)
    var events = winSet(for: .a, games: 6)
    events += winSet(for: .b, games: 6)
    let s = matchState(rules: rules, events: events)
    #expect(!s.isMatchOver)
    #expect(s.isDecidingSet)
}

// MARK: - Undo & replay

@Test func undoRemovesLastPoint() {
    var session = ScoringSession(rules: MatchRules(gamePointStyle: .goldenPoint))
    session.addPoint(for: .a)
    session.addPoint(for: .a)
    #expect(session.state.pointA == 2)
    let undone = session.undo()
    #expect(undone)
    #expect(session.state.pointA == 1)
}

@Test func undoReplayMatchesApplyChain() {
    var session = ScoringSession(rules: MatchRules(gamePointStyle: .goldenPoint))
    let teams: [Team] = [.a, .b, .a, .a, .b, .b, .a]
    for team in teams { session.addPoint(for: team) }
    let before = session.state
    session.undo()
    session.addPoint(for: .a)
    #expect(session.state == before)
}

@Test func multipleUndosWalkBackHistory() {
    var session = ScoringSession(rules: MatchRules(gamePointStyle: .goldenPoint))
    for _ in 0..<8 { session.addPoint(for: .a) }
    #expect(session.state.gamesA == 2)
    session.undo()
    session.undo()
    session.undo()
    session.undo()
    #expect(session.state.gamesA == 1)
}

// MARK: - Idempotency & formatters

@Test func pointsIgnoredAfterMatchOver() {
    var s = matchState(
        rules: MatchRules(setsToWin: 1, gamePointStyle: .goldenPoint),
        events: winSet(for: .a, games: 6)
    )
    let finished = s
    s = ScoringEngine.apply(point: .b, to: s)
    #expect(s == finished)
}

@Test func replayIsDeterministic() {
    let rules = MatchRules(gamePointStyle: .goldenPoint)
    let events: [Team] = [.a, .b, .a, .b, .a, .a]
    let once = matchState(rules: rules, events: events)
    let twice = ScoringEngine.replay(events: events.map { PointEvent(team: $0) }, rules: rules)
    #expect(once == twice)
}

@Test func formatterShowsAdvantage() {
    let s = matchState(
        rules: MatchRules(gamePointStyle: .advantage),
        events: [.a, .a, .b, .b, .a, .b, .a]
    )
    #expect(ScoreFormatter.gamePoints(for: .a, in: s) == "Ad")
    #expect(ScoreFormatter.gamePoints(for: .b, in: s) == "40")
}

@Test func formatterShowsTieBreakDigits() {
    var events = reachGameScore(gamesA: 6, gamesB: 6)
    events += [.a, .a, .b]
    let s = matchState(rules: MatchRules(gamePointStyle: .goldenPoint), events: events)
    #expect(ScoreFormatter.gamePoints(for: .a, in: s) == "2")
    #expect(ScoreFormatter.gamePoints(for: .b, in: s) == "1")
}

@Test func formatterSetSummaryIncludesTieBreak() {
    var events = reachGameScore(gamesA: 6, gamesB: 6)
    events += tieBreakPoints(pointsA: 7, pointsB: 5)
    let s = matchState(rules: MatchRules(gamePointStyle: .goldenPoint), events: events)
    #expect(ScoreFormatter.formatSetScore(s.completedSets[0]) == "7-6 (7-5)")
}

@Test func defaultRulesUseGoldenPoint() {
    #expect(MatchRules.default.gamePointStyle == .goldenPoint)
    #expect(MatchRules.default.finalSetTieBreak == .superTieBreak10)
}

// MARK: - Best-of-1 tie-break

@Test func bestOfOneUsesSetTieBreakAsDecidingTieBreak() {
    let rules = MatchRulesPreferences.makeRules(
        bestOfSets: 1,
        gamePointStyle: .goldenPoint,
        setTieBreak: .classic,
        finalSetTieBreak: .superTieBreak10
    )
    #expect(rules.setsToWin == 1)
    #expect(rules.finalSetTieBreak == .classic)

    var events = reachGameScore(gamesA: 6, gamesB: 6)
    events += tieBreakPoints(pointsA: 7, pointsB: 5)
    let s = matchState(rules: rules, events: events)
    #expect(s.isMatchOver)
    #expect(s.completedSets[0].tieBreakA == 7)
}

// MARK: - Session state cache parity

@Test func sessionStateMatchesReplayAfterAddsAndUndos() {
    let rules = MatchRules(gamePointStyle: .advantage)
    var session = ScoringSession(rules: rules)
    let teams: [Team] = [.a, .b, .a, .a, .b, .b, .a, .b, .a, .a, .b, .a]
    for team in teams { session.addPoint(for: team) }
    session.undo()
    session.undo()
    session.addPoint(for: .b)

    let expected = ScoringEngine.replay(events: session.events, rules: rules)
    #expect(session.state == expected)
}

@Test func sessionInitializedWithEventsMatchesReplay() {
    let rules = MatchRules(setsToWin: 2, gamePointStyle: .goldenPoint)
    var events = winSet(for: .a, games: 6)
    events += reachGameScore(gamesA: 3, gamesB: 2)
    let pointEvents = events.map { PointEvent(team: $0) }

    let session = ScoringSession(rules: rules, events: pointEvents)
    let expected = ScoringEngine.replay(events: pointEvents, rules: rules)
    #expect(session.state == expected)
}
