import PadelCore
import SwiftUI

struct LiveMatchView: View {
    @Environment(PhoneSyncCoordinator.self) private var syncCoordinator
    @Environment(AppThemeStore.self) private var themeStore

    @ScaledMetric(relativeTo: .largeTitle) private var gameScoreFontSize = 56

    private var snapshot: LiveScoreSnapshot? {
        syncCoordinator.liveSnapshot
    }

    private var palette: ThemePalette {
        themeStore.palette
    }

    var body: some View {
        Group {
            if let snapshot {
                liveMirrorView(snapshot)
            } else {
                ContentUnavailableView(
                    String(localized: "No live match"),
                    systemImage: "applewatch",
                    description: Text(String(localized: "Start scoring on your Apple Watch to see the live score here."))
                )
            }
        }
        .navigationTitle(String(localized: "Live match"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func liveMirrorView(_ snapshot: LiveScoreSnapshot) -> some View {
        let playerNames = snapshot.playerNames

        return GeometryReader { _ in
            ZStack {
                VStack(spacing: 0) {
                    phoneTeamZone(
                        team: .b,
                        playerNames: [
                            playerNames.playerB1Name,
                            playerNames.playerB2Name,
                        ].compactMap { $0 },
                        fallbackLabel: playerNames.courtSideLabel(for: .b),
                        snapshot: snapshot
                    )

                    phoneTeamZone(
                        team: .a,
                        playerNames: playerNames.playersInCourtDisplayOrder(for: .a),
                        fallbackLabel: playerNames.courtSideLabel(for: .a),
                        snapshot: snapshot
                    )
                }

                phoneScoreOverlay(snapshot)
            }
        }
        .ignoresSafeArea(edges: [.horizontal, .bottom])
    }

    private func serveSideChip(for side: ServeSide) -> some View {
        Text(side == .right ? "R" : "L")
            .font(.system(size: 11, weight: .black, design: .rounded))
            .foregroundStyle(palette.serveColor)
            .kerning(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(.black.opacity(0.45), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(palette.serveColor, lineWidth: 1)
            }
    }

    private func phoneScoreOverlay(_ snapshot: LiveScoreSnapshot) -> some View {
        VStack(spacing: 8) {
            if !snapshot.completedSetScores.isEmpty {
                HStack(spacing: 8) {
                    ForEach(Array(snapshot.completedSetScores.enumerated()), id: \.offset) { _, score in
                        Text(score)
                    }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            }

            Text(snapshot.setGames)
                .font(.title3.weight(.semibold))

            Text(snapshot.gameScore)
                .font(.system(size: gameScoreFontSize, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 28)
        .padding(.vertical, 18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(scoreAccessibilityLabel(for: snapshot))
        .allowsHitTesting(false)
    }

    private func scoreAccessibilityLabel(for snapshot: LiveScoreSnapshot) -> String {
        let completed = snapshot.completedSetScores.joined(separator: ", ")
        let currentSet = snapshot.setGames
        let game = snapshot.gameScore

        if completed.isEmpty {
            return String(localized: "Set score \(currentSet), game score \(game)")
        }
        return String(localized: "Completed sets \(completed), current set \(currentSet), game score \(game)")
    }

    private func phoneTeamZone(
        team: Team,
        playerNames: [String],
        fallbackLabel: String,
        snapshot: LiveScoreSnapshot
    ) -> some View {
        ZStack {
            palette.gradient(for: team)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            GeometryReader { proxy in
                phoneTeamNameRow(
                    playerNames: playerNames,
                    fallbackLabel: fallbackLabel,
                    snapshot: snapshot
                )
                .padding(.horizontal, 28)
                .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
                .frame(width: proxy.size.width, height: proxy.size.height)
                .offset(y: team == .b ? proxy.size.height * 0.05 : 0)
            }
        }
        .overlay(alignment: serveAlignment(for: team, snapshot: snapshot)) {
            serveIndicator(for: team, snapshot: snapshot)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(teamAccessibilityLabel(for: team, label: fallbackLabel, playerNames: playerNames, snapshot: snapshot))
    }

    @ViewBuilder
    private func phoneTeamNameRow(
        playerNames: [String],
        fallbackLabel: String,
        snapshot: LiveScoreSnapshot
    ) -> some View {
        if playerNames.count >= 2 {
            HStack(spacing: 0) {
                playerNameLabel(name: playerNames[0], snapshot: snapshot)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 32)

                playerNameLabel(name: playerNames[1], snapshot: snapshot)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        } else {
            Text(fallbackLabel)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
    }

    private func playerNameLabel(name: String, snapshot: LiveScoreSnapshot) -> some View {
        let isServing = snapshot.servingPlayerName == name
        return Text(name)
            .font(.title2.weight(isServing ? .bold : .semibold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, isServing ? 12 : 0)
            .padding(.vertical, isServing ? 6 : 0)
            .background(isServing ? .black.opacity(0.5) : .clear, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(isServing ? palette.serveColor : .clear, lineWidth: 1)
            }
    }

    @ViewBuilder
    private func serveIndicator(for team: Team, snapshot: LiveScoreSnapshot) -> some View {
        if let serveSide = snapshot.serveSide, snapshot.servingTeam == team {
            switch themeStore.serveIndicatorStyle {
            case .sideLabels:
                serveSideChip(for: serveSide)
                    .shadow(color: .black.opacity(0.5), radius: 4, y: 2)
                    .padding(team == .a ? .top : .bottom, 18)
                    .padding(.horizontal, 24)
                    .accessibilityHidden(true)
            case .movingBall:
                ServeBallIndicator(color: palette.serveColor, atTopEdge: team == .a)
            }
        }
    }

    private func serveAlignment(for team: Team, snapshot: LiveScoreSnapshot) -> Alignment {
        let vertical: VerticalAlignment = team == .a ? .top : .bottom
        let onRight = snapshot.serveSide == .right
        let trailing = team == .a ? onRight : !onRight
        let horizontal: HorizontalAlignment = trailing ? .trailing : .leading
        return Alignment(horizontal: horizontal, vertical: vertical)
    }

    private func teamAccessibilityLabel(
        for team: Team,
        label: String,
        playerNames: [String],
        snapshot: LiveScoreSnapshot
    ) -> String {
        guard let serveSide = snapshot.serveSide, snapshot.servingTeam == team else {
            return label
        }
        let side = serveSide == .right
            ? String(localized: "right")
            : String(localized: "left")
        if let serverName = snapshot.servingPlayerName {
            return String(localized: "\(label). \(serverName) serving from the \(side).")
        }
        return String(localized: "\(label). Serving from the \(side).")
    }
}

#Preview {
    let coordinator = PhoneSyncCoordinator(syncListener: PhoneConnectivityListener())
    coordinator.liveSnapshot = LiveScoreSnapshot(
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

    return NavigationStack {
        LiveMatchView()
    }
    .environment(coordinator)
    .environment(AppThemeStore())
}
