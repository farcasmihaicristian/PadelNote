import PadelCore
import SwiftUI

struct MatchRowView: View {
    let match: Match

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(MatchFormatting.dayTitle(for: match.startedAt))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(match.scoreSummary)
                .font(.headline)

            Text(MatchFormatting.winnerLabel(for: match))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            String(
                localized: "\(MatchFormatting.dayTitle(for: match.startedAt)), score \(match.scoreSummary), winner \(MatchFormatting.winnerLabel(for: match))"
            )
        )
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
            teamAName: "Alex & Maria",
            teamBName: "Chris & Dana"
        ))
    }
}
