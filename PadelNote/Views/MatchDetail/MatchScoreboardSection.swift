import PadelCore
import SwiftUI

/// Broadcast-style score card: one row per team with games for each set, the
/// winner marked with a trophy. Your team is listed first when you played.
struct MatchScoreboardSection: View {
    let match: Match
    let perspective: MatchPerspective?

    var body: some View {
        let teams: [Team] = perspective.map { [$0.myTeam, $0.myTeam.opponent] } ?? [.a, .b]
        let sets = match.completedSets
        let partial = partialGames
        let winner = match.resolvedWinner

        Section {
            VStack(spacing: 12) {
                ForEach(teams, id: \.self) { team in
                    row(for: team, sets: sets, partial: partial, isWinner: winner == team)
                }
            }
            .padding(.vertical, 4)

            if winner == nil {
                Text(MatchFormatting.winnerLabel(for: match))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text(String(localized: "Final score"))
        }
    }

    private var partialGames: (a: Int, b: Int)? {
        guard match.inProgressSetSummary != nil else { return nil }
        let state = match.replayedState()
        return (state.gamesA, state.gamesB)
    }

    private func row(
        for team: Team,
        sets: [SetScore],
        partial: (a: Int, b: Int)?,
        isWinner: Bool
    ) -> some View {
        let names = match.players(for: team)
        let title = names.isEmpty ? match.teamName(for: team) : names.joined(separator: " / ")
        let isMyTeam = perspective?.myTeam == team

        return HStack(spacing: 10) {
            Image(systemName: "trophy.fill")
                .font(.subheadline)
                .foregroundStyle(.yellow)
                .opacity(isWinner ? 1 : 0)
                .frame(width: 20)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline.weight(isWinner ? .bold : .regular))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                if isMyTeam {
                    Text(String(localized: "Your team"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            HStack(spacing: 14) {
                ForEach(Array(sets.enumerated()), id: \.offset) { _, set in
                    setCell(for: team, in: set)
                }
                if let partial {
                    Text("\(team == .a ? partial.a : partial.b)")
                        .font(.title3.monospacedDigit())
                        .foregroundStyle(.red)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(rowAccessibilityLabel(title: title, team: team, sets: sets, partial: partial, isWinner: isWinner))
    }

    private func setCell(for team: Team, in set: SetScore) -> some View {
        let games = team == .a ? set.gamesA : set.gamesB
        let tieBreak = team == .a ? set.tieBreakA : set.tieBreakB
        let wonSet = set.winner == team

        return HStack(alignment: .top, spacing: 1) {
            Text("\(games)")
                .font(.title3.monospacedDigit().weight(wonSet ? .bold : .regular))
                .foregroundStyle(wonSet ? .primary : .secondary)
            if let tieBreak {
                Text("\(tieBreak)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .frame(minWidth: 18)
    }

    private func rowAccessibilityLabel(
        title: String,
        team: Team,
        sets: [SetScore],
        partial: (a: Int, b: Int)?,
        isWinner: Bool
    ) -> String {
        var games = sets.map { "\(team == .a ? $0.gamesA : $0.gamesB)" }
        if let partial {
            games.append(String(localized: "unfinished set \(team == .a ? partial.a : partial.b)"))
        }
        let gamesText = games.joined(separator: ", ")
        return isWinner
            ? String(localized: "\(title), winner, games \(gamesText)")
            : String(localized: "\(title), games \(gamesText)")
    }
}
