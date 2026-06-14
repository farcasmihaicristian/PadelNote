import Foundation

public enum MatchStatistics {
    public static func insights(for summaries: [MatchSummary]) -> MatchInsights {
        let completed = summaries.filter(\.isCompleted)
        guard !completed.isEmpty else { return .empty }

        let decided = completed.filter { $0.winner != nil }
        let teamAWins = decided.filter { $0.winner == .a }.count
        let teamBWins = decided.filter { $0.winner == .b }.count

        let durations = completed.compactMap(\.duration)
        let averageDuration = durations.isEmpty
            ? nil
            : durations.reduce(0, +) / Double(durations.count)
        let longestDuration = durations.max()

        var goldenPointOpportunities = 0
        var goldenPointWinsByTeamA = 0

        for summary in completed {
            let counts = goldenPointCounts(for: summary)
            goldenPointOpportunities += counts.opportunities
            goldenPointWinsByTeamA += counts.winsByTeamA
        }

        return MatchInsights(
            completedMatchCount: completed.count,
            decidedMatchCount: decided.count,
            teamAWins: teamAWins,
            teamBWins: teamBWins,
            teamAWinRate: decided.isEmpty ? nil : Double(teamAWins) / Double(decided.count),
            averageDuration: averageDuration,
            longestDuration: longestDuration,
            goldenPointOpportunities: goldenPointOpportunities,
            goldenPointWinsByTeamA: goldenPointWinsByTeamA,
            goldenPointConversionRate: goldenPointOpportunities == 0
                ? nil
                : Double(goldenPointWinsByTeamA) / Double(goldenPointOpportunities)
        )
    }

    private static func goldenPointCounts(for summary: MatchSummary) -> (opportunities: Int, winsByTeamA: Int) {
        var state = MatchState(rules: summary.rules)
        var opportunities = 0
        var winsByTeamA = 0

        for event in summary.events {
            guard !state.isMatchOver else { break }

            if isGoldenPointSituation(state) {
                opportunities += 1
                let gamesBefore = state.gamesA + state.gamesB
                state = ScoringEngine.apply(point: event.team, to: state)
                let gamesAfter = state.gamesA + state.gamesB
                if gamesAfter > gamesBefore, event.team == .a {
                    winsByTeamA += 1
                }
            } else {
                state = ScoringEngine.apply(point: event.team, to: state)
            }
        }

        return (opportunities, winsByTeamA)
    }

    private static func isGoldenPointSituation(_ state: MatchState) -> Bool {
        guard !state.isTieBreak,
              state.pointA == 3,
              state.pointB == 3,
              state.advantageTeam == nil
        else { return false }

        switch state.rules.gamePointStyle {
        case .goldenPoint:
            return true
        case .starPoint:
            return state.deuceCount >= 3
        case .advantage:
            return false
        }
    }
}
