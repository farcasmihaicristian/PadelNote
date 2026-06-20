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

                if let serveText {
                    LabeledContent(String(localized: "Serving")) {
                        Label(serveText, systemImage: "arrowtriangle.right.fill")
                            .labelStyle(.titleAndIcon)
                            .foregroundStyle(.orange)
                    }
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

    private var serveText: String? {
        guard !snapshot.isMatchOver, let side = snapshot.serveSide else { return nil }
        let server = snapshot.servingPlayerName
            ?? snapshot.servingTeam.map { snapshot.teamLabel(for: $0) }
            ?? String(localized: "Server")
        let sideText = side == .right
            ? String(localized: "right")
            : String(localized: "left")
        return String(localized: "\(server) · \(sideText)")
    }
}

#Preview {
    NavigationStack {
        WatchLiveMirrorView(
            snapshot: LiveScoreSnapshot(
                matchID: UUID(),
                state: ScoringEngine.replay(events: [.init(team: .a), .init(team: .b)], rules: .default),
                playerNames: MatchPlayerNames(
                    playerA1: "Alex",
                    playerA2: "Maria",
                    playerB1: "Chris",
                    playerB2: "Dana"
                ),
                pointCount: 2
            )
        )
    }
}
