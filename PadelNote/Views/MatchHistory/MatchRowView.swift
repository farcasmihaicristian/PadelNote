import PadelCore
import SwiftUI

struct MatchRowView: View {
    let match: Match
    var focusPlayerID: UUID?

    var body: some View {
        let score = MatchScoreText.rendered(for: match)
        return VStack(alignment: .leading, spacing: 4) {
            Text(MatchFormatting.dayTitle(for: match.startedAt))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            score.text
                .font(.headline)

            if let focusPlayerID,
               let placement = match.roster.placementDescription(for: focusPlayerID) {
                Text(placement)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(MatchFormatting.winnerLabel(for: match))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(score: score))
    }

    private func accessibilityLabel(score: MatchScoreText.Rendered) -> String {
        var parts = [
            MatchFormatting.dayTitle(for: match.startedAt),
            String(localized: "score \(score.accessibilityLabel)"),
            String(localized: "winner \(MatchFormatting.winnerLabel(for: match))"),
        ]

        if let focusPlayerID,
           let placement = match.roster.placementDescription(for: focusPlayerID) {
            parts.append(String(localized: "played \(placement)"))
        }

        return parts.joined(separator: ", ")
    }
}

#Preview {
    List {
        MatchRowView(match: Match(
            startedAt: .now,
            endedAt: .now.addingTimeInterval(3600),
            rules: .default,
            completedSets: [SetScore(gamesA: 6, gamesB: 4), SetScore(gamesA: 6, gamesB: 3)],
            winner: .a,
            playerNames: MatchPlayerNames(
                playerA1: "Alex",
                playerA2: "Maria",
                playerB1: "Chris",
                playerB2: "Dana"
            )
        ))
    }
}
