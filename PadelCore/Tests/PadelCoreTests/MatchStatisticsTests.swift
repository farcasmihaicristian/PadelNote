import Foundation
import Testing
@testable import PadelCore

@Test func insightsEmptyWhenNoCompletedMatches() {
    let insights = MatchStatistics.insights(for: [])
    #expect(insights == .empty)
}

@Test func insightsComputesWinRateAndDuration() {
    let rules = MatchRules(setsToWin: 1, gamePointStyle: .goldenPoint)
    let eventsA: [PointEvent] = (0..<6).flatMap { _ in [PointEvent(team: .a), .init(team: .a), .init(team: .a), .init(team: .a)] }
    let eventsB: [PointEvent] = (0..<6).flatMap { _ in [PointEvent(team: .b), .init(team: .b), .init(team: .b), .init(team: .b)] }
    let stateA = ScoringEngine.replay(events: eventsA, rules: rules)
    let stateB = ScoringEngine.replay(events: eventsB, rules: rules)

    let summaries = [
        MatchSummary(
            rules: rules,
            events: eventsA,
            winner: stateA.winner,
            duration: 60 * 60,
            isCompleted: true
        ),
        MatchSummary(
            rules: rules,
            events: eventsB,
            winner: stateB.winner,
            duration: 30 * 60,
            isCompleted: true
        ),
    ]

    let insights = MatchStatistics.insights(for: summaries)
    #expect(insights.completedMatchCount == 2)
    #expect(insights.decidedMatchCount == 2)
    #expect(insights.teamAWins == 1)
    #expect(insights.teamBWins == 1)
    #expect(insights.teamAWinRate == 0.5)
    #expect(insights.averageDuration == Double(45 * 60))
    #expect(insights.longestDuration == Double(60 * 60))
}

@Test func insightsTracksGoldenPointConversionForTeamA() {
    let events: [PointEvent] = [.a, .a, .a, .b, .b, .b, .a].map { PointEvent(team: $0) }
    let state = ScoringEngine.replay(
        events: events,
        rules: MatchRules(setsToWin: 1, gamePointStyle: .goldenPoint)
    )

    let summary = MatchSummary(
        rules: MatchRules(setsToWin: 1, gamePointStyle: .goldenPoint),
        events: events,
        winner: state.winner,
        duration: 15 * 60,
        isCompleted: true
    )

    let insights = MatchStatistics.insights(for: [summary])
    #expect(insights.goldenPointOpportunities == 1)
    #expect(insights.goldenPointWinsByTeamA == 1)
    #expect(insights.goldenPointConversionRate == 1)
}

@Test func insightsIgnoresIncompleteMatches() {
    let summaries = [
        MatchSummary(
            rules: .default,
            events: [PointEvent(team: .a)],
            winner: nil,
            duration: nil,
            isCompleted: false
        )
    ]

    let insights = MatchStatistics.insights(for: summaries)
    #expect(insights == .empty)
}
