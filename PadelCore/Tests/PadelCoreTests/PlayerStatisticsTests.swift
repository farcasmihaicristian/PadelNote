import Foundation
import Testing
@testable import PadelCore

@Test func playerSummariesAggregateWinRateBySide() {
    let alexID = UUID()
    let mariaID = UUID()
    let chrisID = UUID()
    let danaID = UUID()

    let rules = MatchRules(setsToWin: 1, gamePointStyle: .goldenPoint)
    let eventsA: [PointEvent] = (0..<6).flatMap { _ in [PointEvent(team: .a), .init(team: .a), .init(team: .a), .init(team: .a)] }
    let eventsB: [PointEvent] = (0..<6).flatMap { _ in [PointEvent(team: .b), .init(team: .b), .init(team: .b), .init(team: .b)] }
    let stateA = ScoringEngine.replay(events: eventsA, rules: rules)
    let stateB = ScoringEngine.replay(events: eventsB, rules: rules)

    let rosterA = MatchRoster(
        playerA1ID: alexID, playerA1Name: "Alex",
        playerA2ID: mariaID, playerA2Name: "Maria",
        playerB1ID: chrisID, playerB1Name: "Chris",
        playerB2ID: danaID, playerB2Name: "Dana"
    )
    let rosterB = MatchRoster(
        playerA1ID: alexID, playerA1Name: "Alex",
        playerA2ID: mariaID, playerA2Name: "Maria",
        playerB1ID: chrisID, playerB1Name: "Chris",
        playerB2ID: danaID, playerB2Name: "Dana"
    )

    let summaries = [
        MatchSummary(
            rules: rules,
            events: eventsA,
            winner: stateA.winner,
            duration: 60 * 60,
            isCompleted: true,
            roster: rosterA
        ),
        MatchSummary(
            rules: rules,
            events: eventsB,
            winner: stateB.winner,
            duration: 30 * 60,
            isCompleted: true,
            roster: rosterB
        ),
    ]

    let names = [
        alexID: "Alex",
        mariaID: "Maria",
        chrisID: "Chris",
        danaID: "Dana",
    ]

    let summariesList = MatchStatistics.playerSummaries(for: summaries, displayNames: names)

    #expect(summariesList.count == 4)
    #expect(summariesList.first(where: { $0.id == alexID })?.matchCount == 2)
    #expect(summariesList.first(where: { $0.id == alexID })?.wins == 1)
    #expect(summariesList.first(where: { $0.id == alexID })?.losses == 1)
    #expect(summariesList.first(where: { $0.id == alexID })?.winRate == 0.5)
    #expect(summariesList.first(where: { $0.id == chrisID })?.wins == 1)
}

@Test func playerInsightsTracksSideSpecificGoldenPointConversion() {
    let alexID = UUID()
    let events: [PointEvent] = [.a, .a, .a, .b, .b, .b, .a].map { PointEvent(team: $0) }
    let rules = MatchRules(setsToWin: 1, gamePointStyle: .goldenPoint)
    let state = ScoringEngine.replay(events: events, rules: rules)
    let roster = MatchRoster(
        playerA1ID: alexID, playerA1Name: "Alex",
        playerA2ID: nil, playerA2Name: nil,
        playerB1ID: nil, playerB1Name: nil,
        playerB2ID: nil, playerB2Name: nil
    )

    let summary = MatchSummary(
        rules: rules,
        events: events,
        winner: state.winner,
        duration: 900,
        isCompleted: true,
        roster: roster
    )

    let insights = MatchStatistics.playerInsights(
        for: alexID,
        displayName: "Alex",
        in: [summary]
    )

    #expect(insights.matchCount == 1)
    #expect(insights.goldenPointOpportunities == 1)
    #expect(insights.goldenPointWins == 1)
    #expect(insights.goldenPointConversionRate == 1)
}

@Test func playerSummariesIgnoreMatchesWithoutLinkedPlayers() {
    let summary = MatchSummary(
        rules: .default,
        events: [PointEvent(team: .a)],
        winner: .a,
        duration: 600,
        isCompleted: true,
        roster: .empty
    )

    let summaries = MatchStatistics.playerSummaries(for: [summary], displayNames: [:])
    #expect(summaries.isEmpty)
}

@Test func normalizeNameDeduplicatesCaseAndWhitespace() {
    #expect(PlayerPersistence.normalizeName("  Alex ") == PlayerPersistence.normalizeName("alex"))
}

@Test func rosterTracksPlayerCourtSide() {
    let alexID = UUID()
    let roster = MatchRoster(
        playerA1ID: alexID, playerA1Name: "Alex",
        playerA2ID: nil, playerA2Name: "Maria",
        playerB1ID: nil, playerB1Name: "Chris",
        playerB2ID: nil, playerB2Name: "Dana"
    )

    #expect(roster.team(for: alexID) == .a)
    #expect(roster.courtSide(for: alexID) == .right)
    #expect(roster.placementDescription(for: alexID) == "Right side")
}

@Test func playerInsightsSplitWinRateByLeftAndRightSide() {
    let alexID = UUID()
    let rules = MatchRules(setsToWin: 1, gamePointStyle: .goldenPoint)
    // One full set (6-0) per match.
    let setWinA: [PointEvent] = (0..<6).flatMap { _ in (0..<4).map { _ in PointEvent(team: .a) } }
    let setWinB: [PointEvent] = (0..<6).flatMap { _ in (0..<4).map { _ in PointEvent(team: .b) } }

    // Alex on the right (player 1 = index 0).
    let alexRightRoster = MatchRoster(
        playerA1ID: alexID, playerA1Name: "Alex",
        playerA2ID: nil, playerA2Name: "Maria",
        playerB1ID: nil, playerB1Name: "Chris",
        playerB2ID: nil, playerB2Name: "Dana"
    )
    // Alex on the left (player 2 = index 1).
    let alexLeftRoster = MatchRoster(
        playerA1ID: nil, playerA1Name: "Maria",
        playerA2ID: alexID, playerA2Name: "Alex",
        playerB1ID: nil, playerB1Name: "Chris",
        playerB2ID: nil, playerB2Name: "Dana"
    )

    let summaries = [
        MatchSummary(
            rules: rules,
            events: setWinA,
            winner: .a,
            duration: 3600,
            isCompleted: true,
            roster: alexRightRoster
        ),
        MatchSummary(
            rules: rules,
            events: setWinA,
            winner: .a,
            duration: 3600,
            isCompleted: true,
            roster: alexRightRoster
        ),
        MatchSummary(
            rules: rules,
            events: setWinB,
            winner: .b,
            duration: 3600,
            isCompleted: true,
            roster: alexLeftRoster
        ),
    ]

    let insights = MatchStatistics.playerInsights(
        for: alexID,
        displayName: "Alex",
        in: summaries
    )

    #expect(insights.matchCount == 3)
    #expect(insights.leftSideStats.matchCount == 1)
    #expect(insights.leftSideStats.losses == 1)
    #expect(insights.leftSideStats.winRate == 0)
    #expect(insights.rightSideStats.matchCount == 2)
    #expect(insights.rightSideStats.wins == 2)
    #expect(insights.rightSideStats.winRate == 1)
}

@Test func playerInsightsTracksSideChangesPerSet() {
    let alexID = UUID()
    let rules = MatchRules(setsToWin: 2, gamePointStyle: .goldenPoint)
    let setWinA: [PointEvent] = (0..<6).flatMap { _ in (0..<4).map { _ in PointEvent(team: .a) } }
    let setWinB: [PointEvent] = (0..<6).flatMap { _ in (0..<4).map { _ in PointEvent(team: .b) } }
    // A wins set 1, B wins set 2, A wins set 3 -> A takes the match 2-1.
    let events = setWinA + setWinB + setWinA

    let alexRightRoster = MatchRoster(
        playerA1ID: alexID, playerA1Name: "Alex",
        playerA2ID: nil, playerA2Name: "Maria",
        playerB1ID: nil, playerB1Name: "Chris",
        playerB2ID: nil, playerB2Name: "Dana"
    )
    let alexLeftRoster = MatchRoster(
        playerA1ID: nil, playerA1Name: "Maria",
        playerA2ID: alexID, playerA2Name: "Alex",
        playerB1ID: nil, playerB1Name: "Chris",
        playerB2ID: nil, playerB2Name: "Dana"
    )

    // Alex starts on the right, then switches to the left from set 2 onward.
    let summary = MatchSummary(
        rules: rules,
        events: events,
        winner: .a,
        duration: 3600,
        isCompleted: true,
        roster: alexRightRoster,
        setRosters: [alexRightRoster, alexLeftRoster, alexLeftRoster]
    )

    let insights = MatchStatistics.playerInsights(
        for: alexID,
        displayName: "Alex",
        in: [summary]
    )

    #expect(insights.matchCount == 1)
    #expect(insights.wins == 1)
    // Set 1 on the right (won).
    #expect(insights.rightSideStats.matchCount == 1)
    #expect(insights.rightSideStats.wins == 1)
    #expect(insights.rightSideStats.winRate == 1)
    // Sets 2 (lost) and 3 (won) on the left.
    #expect(insights.leftSideStats.matchCount == 2)
    #expect(insights.leftSideStats.wins == 1)
    #expect(insights.leftSideStats.losses == 1)
    #expect(insights.leftSideStats.winRate == 0.5)
}
