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

    public static func partnerStats(
        for playerID: UUID,
        in summaries: [MatchSummary],
        displayNames: [UUID: String]
    ) -> [PartnerSummary] {
        let completed = summaries.filter { summary in
            summary.isCompleted && summary.roster.contains(playerID: playerID)
        }

        var matchCounts: [UUID: Int] = [:]
        var wins: [UUID: Int] = [:]
        var losses: [UUID: Int] = [:]

        for summary in completed {
            let partners = summary.roster.partnerIDs(for: playerID)
            guard !partners.isEmpty else { continue }

            for partnerID in partners {
                matchCounts[partnerID, default: 0] += 1

                guard let winner = summary.winner,
                      let team = summary.roster.team(for: playerID)
                else { continue }

                if winner == team {
                    wins[partnerID, default: 0] += 1
                } else {
                    losses[partnerID, default: 0] += 1
                }
            }
        }

        return matchCounts.keys
            .map { partnerID in
                let decided = wins[partnerID, default: 0] + losses[partnerID, default: 0]
                return PartnerSummary(
                    id: partnerID,
                    displayName: displayNames[partnerID] ?? String(localized: "Unknown player"),
                    matchCount: matchCounts[partnerID, default: 0],
                    wins: wins[partnerID, default: 0],
                    losses: losses[partnerID, default: 0],
                    winRate: decided == 0 ? nil : Double(wins[partnerID, default: 0]) / Double(decided)
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

        var leftSets = 0
        var leftWins = 0
        var leftLosses = 0
        var rightSets = 0
        var rightWins = 0
        var rightLosses = 0

        var servePointsPlayed = 0
        var servePointsWon = 0
        var serviceGamesPlayed = 0
        var serviceGamesHeld = 0

        for summary in completed {
            if let duration = summary.duration {
                durations.append(duration)
            }

            guard let team = summary.roster.team(for: playerID) else { continue }

            // Serve attribution. Only matches recorded with serve tracking
            // contribute, so legacy matches don't get a default rotation applied.
            if !summary.setServeOrders.isEmpty {
                let timeline = ServeEngine.timeline(
                    events: summary.events,
                    rules: summary.rules,
                    orders: summary.setServeOrders
                )

                for point in timeline.points {
                    let roster = summary.setRosters[safe: point.setIndex] ?? summary.roster
                    guard serverID(for: point.servingSlot, in: roster) == playerID else { continue }
                    servePointsPlayed += 1
                    if point.winner == point.servingTeam {
                        servePointsWon += 1
                    }
                }

                for game in timeline.games where !game.isTieBreak {
                    let roster = summary.setRosters[safe: game.setIndex] ?? summary.roster
                    guard serverID(for: game.serverSlot, in: roster) == playerID else { continue }
                    serviceGamesPlayed += 1
                    if game.held {
                        serviceGamesHeld += 1
                    }
                }
            }

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

            // Per-set side attribution: each completed set is credited to the
            // side the player occupied during that set (falling back to the
            // canonical lineup when no per-set data was recorded). Reuses the
            // sets from the single replay above rather than replaying again.
            let completedSets = goldenCounts.completedSets

            for (index, set) in completedSets.enumerated() {
                let roster = summary.setRosters[safe: index] ?? summary.roster
                guard let courtSide = roster.courtSide(for: playerID) else { continue }

                let won = set.winner == team
                switch courtSide {
                case .left:
                    leftSets += 1
                    if won { leftWins += 1 } else { leftLosses += 1 }
                case .right:
                    rightSets += 1
                    if won { rightWins += 1 } else { rightLosses += 1 }
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
                : Double(goldenPointWins) / Double(goldenPointOpportunities),
            leftSideStats: rolePerformanceStats(
                matchCount: leftSets,
                wins: leftWins,
                losses: leftLosses
            ),
            rightSideStats: rolePerformanceStats(
                matchCount: rightSets,
                wins: rightWins,
                losses: rightLosses
            ),
            servePointsPlayed: servePointsPlayed,
            servePointsWon: servePointsWon,
            servePointWinRate: servePointsPlayed == 0
                ? nil
                : Double(servePointsWon) / Double(servePointsPlayed),
            serviceGamesPlayed: serviceGamesPlayed,
            serviceGamesHeld: serviceGamesHeld,
            serviceGamesBroken: serviceGamesPlayed - serviceGamesHeld,
            serviceHoldRate: serviceGamesPlayed == 0
                ? nil
                : Double(serviceGamesHeld) / Double(serviceGamesPlayed)
        )
    }

    /// Maps a serving slot to the player occupying that position in a set's roster.
    private static func serverID(for slot: PlayerSlot, in roster: MatchRoster) -> UUID? {
        switch slot {
        case .sideAPlayer1: roster.sideA[safe: 0]?.id
        case .sideAPlayer2: roster.sideA[safe: 1]?.id
        case .sideBPlayer1: roster.sideB[safe: 0]?.id
        case .sideBPlayer2: roster.sideB[safe: 1]?.id
        }
    }

    private static func rolePerformanceStats(
        matchCount: Int,
        wins: Int,
        losses: Int
    ) -> RolePerformanceStats {
        let decided = wins + losses
        return RolePerformanceStats(
            matchCount: matchCount,
            wins: wins,
            losses: losses,
            winRate: decided == 0 ? nil : Double(wins) / Double(decided)
        )
    }

    /// Single replay of a match: counts golden/sudden-death opportunities and
    /// wins for `team`, and returns the final completed sets so callers don't
    /// have to replay the match a second time for set data.
    private static func goldenPointCounts(
        for summary: MatchSummary,
        team: Team
    ) -> (opportunities: Int, wins: Int, completedSets: [SetScore]) {
        var state = MatchState(rules: summary.rules)
        var opportunities = 0
        var wins = 0

        for event in summary.events {
            guard !state.isMatchOver else { break }

            if state.isSuddenDeathPoint {
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

        return (opportunities, wins, state.completedSets)
    }
}
