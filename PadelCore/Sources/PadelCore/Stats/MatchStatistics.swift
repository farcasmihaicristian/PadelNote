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
            let counts = goldenPointCounts(for: summary, team: .a)
            goldenPointOpportunities += counts.opportunities
            goldenPointWinsByTeamA += counts.wins
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

    public static func playerSummaries(
        for summaries: [MatchSummary],
        displayNames: [UUID: String]
    ) -> [PlayerSummary] {
        let completed = summaries.filter(\.isCompleted)
        var matchCounts: [UUID: Int] = [:]
        var wins: [UUID: Int] = [:]
        var losses: [UUID: Int] = [:]

        for summary in completed {
            let playerIDs = summary.roster.linkedPlayerIDs
            guard !playerIDs.isEmpty else { continue }

            for playerID in playerIDs {
                matchCounts[playerID, default: 0] += 1

                guard let winner = summary.winner,
                      let team = summary.roster.team(for: playerID)
                else { continue }

                if winner == team {
                    wins[playerID, default: 0] += 1
                } else {
                    losses[playerID, default: 0] += 1
                }
            }
        }

        return matchCounts.keys
            .map { playerID in
                let decided = wins[playerID, default: 0] + losses[playerID, default: 0]
                return PlayerSummary(
                    id: playerID,
                    displayName: displayNames[playerID] ?? String(localized: "Unknown player"),
                    matchCount: matchCounts[playerID, default: 0],
                    wins: wins[playerID, default: 0],
                    losses: losses[playerID, default: 0],
                    winRate: decided == 0 ? nil : Double(wins[playerID, default: 0]) / Double(decided)
                )
            }
            .sorted {
                if $0.matchCount != $1.matchCount { return $0.matchCount > $1.matchCount }
                return $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
    }

    public static func playerInsights(
        for playerID: UUID,
        displayName: String,
        in summaries: [MatchSummary]
    ) -> PlayerInsights {
        let completed = summaries.filter { summary in
            summary.isCompleted && summary.roster.contains(playerID: playerID)
        }

        guard !completed.isEmpty else {
            return .empty(playerID: playerID, displayName: displayName)
        }

        var wins = 0
        var losses = 0
        var goldenPointOpportunities = 0
        var goldenPointWins = 0
        var durations: [TimeInterval] = []

        for summary in completed {
            if let duration = summary.duration {
                durations.append(duration)
            }

            if let team = summary.roster.team(for: playerID) {
                let goldenCounts = goldenPointCounts(for: summary, team: team)
                goldenPointOpportunities += goldenCounts.opportunities
                goldenPointWins += goldenCounts.wins

                if let winner = summary.winner {
                    if winner == team {
                        wins += 1
                    } else {
                        losses += 1
                    }
                }
            }
        }

        let decided = wins + losses

        return PlayerInsights(
            playerID: playerID,
            displayName: displayName,
            matchCount: completed.count,
            decidedMatchCount: decided,
            wins: wins,
            losses: losses,
            winRate: decided == 0 ? nil : Double(wins) / Double(decided),
            averageDuration: durations.isEmpty ? nil : durations.reduce(0, +) / Double(durations.count),
            goldenPointOpportunities: goldenPointOpportunities,
            goldenPointWins: goldenPointWins,
            goldenPointConversionRate: goldenPointOpportunities == 0
                ? nil
                : Double(goldenPointWins) / Double(goldenPointOpportunities)
        )
    }

    private static func goldenPointCounts(
        for summary: MatchSummary,
        team: Team
    ) -> (opportunities: Int, wins: Int) {
        var state = MatchState(rules: summary.rules)
        var opportunities = 0
        var wins = 0

        for event in summary.events {
            guard !state.isMatchOver else { break }

            if isGoldenPointSituation(state) {
                opportunities += 1
                let gamesBefore = state.gamesA + state.gamesB
                state = ScoringEngine.apply(point: event.team, to: state)
                let gamesAfter = state.gamesA + state.gamesB
                if gamesAfter > gamesBefore, event.team == team {
                    wins += 1
                }
            } else {
                state = ScoringEngine.apply(point: event.team, to: state)
            }
        }

        return (opportunities, wins)
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
