import PadelCore
import SwiftUI

struct WatchLiveMirrorView: View {
    let snapshot: LiveScoreSnapshot

    var body: some View {
        List {
            Section {
                Text(snapshot.scoreLine)
                    .font(.title.bold())
                    .accessibilityLabel(String(localized: "Live score \(snapshot.scoreLine)"))

                LabeledContent(String(localized: "Game")) {
                    Text(snapshot.gameScore)
                }

                LabeledContent(String(localized: "Set games")) {
                    Text(snapshot.setGames)
                }

                LabeledContent(String(localized: "Points played")) {
                    Text("\(snapshot.pointCount)")
                }
            } header: {
                Label(String(localized: "Live on Apple Watch"), systemImage: "applewatch")
            }

            if snapshot.isMatchOver {
                Section {
                    Text(String(localized: "Match ended on Apple Watch. Save it on your watch to sync history."))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(String(localized: "Watch match"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        WatchLiveMirrorView(
            snapshot: LiveScoreSnapshot(
                matchID: UUID(),
                state: ScoringEngine.replay(events: [.init(team: .a), .init(team: .b)], rules: .default),
                teamAName: "Team A",
                teamBName: "Team B",
                pointCount: 2
            )
        )
    }
}
