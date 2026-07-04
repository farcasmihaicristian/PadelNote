import PadelCore
import SwiftUI

struct WatchLiveMatchView: View {
    @Environment(AppThemeStore.self) private var themeStore
    @Bindable var coordinator: WatchMatchCoordinator
    @State private var showEndConfirmation = false
    @State private var showCourtOptions = false
    @State private var showServeSidePrompt = false

    private var state: MatchState {
        // In `.live` a session always exists; the fallback is the empty state and
        // doesn't need a replay to construct.
        coordinator.currentState ?? MatchState(rules: coordinator.rules)
    }

    private var serve: ServeContext? {
        coordinator.currentServe
    }

    private var palette: ThemePalette {
        themeStore.palette
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                teamZone(
                    team: .b,
                    playerNames: [
                        coordinator.activePlayerNames.playerB1Name,
                        coordinator.activePlayerNames.playerB2Name,
                    ].compactMap { $0 },
                    playerSlots: [.sideBPlayer1, .sideBPlayer2],
                    fallbackLabel: coordinator.displaySideLabel(for: .b)
                )

                teamZone(
                    team: .a,
                    playerNames: coordinator.activePlayerNames.playersInCourtDisplayOrder(for: .a),
                    playerSlots: [.sideAPlayer2, .sideAPlayer1],
                    fallbackLabel: coordinator.displaySideLabel(for: .a)
                )
            }

            scoreOverlay

            HStack(spacing: 0) {
                courtOptionsEdgeZone
                Spacer(minLength: 0)
            }
        }
        .ignoresSafeArea()
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                liveControlButton(String(localized: "End")) {
                    showEndConfirmation = true
                }
                .disabled(coordinator.session?.events.isEmpty ?? true)
                .accessibilityLabel(String(localized: "End match"))
            }

            ToolbarItem(placement: .topBarTrailing) {
                liveControlButton(String(localized: "Undo")) {
                    coordinator.undo()
                }
                .disabled(coordinator.session?.events.isEmpty ?? true)
                .accessibilityLabel(String(localized: "Undo last point"))
            }
        }
        .navigationDestination(isPresented: $showCourtOptions) {
            WatchLiveMatchOptionsView(coordinator: coordinator, isPresented: $showCourtOptions)
        }
        .confirmationDialog(
            String(localized: "End this match?"),
            isPresented: $showEndConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: "End match"), role: .destructive) {
                coordinator.endMatchEarly()
            }
            Button(String(localized: "Cancel"), role: .cancel) {}
        }
        .confirmationDialog(
            String(localized: "Deciding point — receiver picks the serve side"),
            isPresented: $showServeSidePrompt,
            titleVisibility: .visible
        ) {
            Button(String(localized: "Serve from right")) {
                coordinator.chooseDecidingSide(.right)
            }
            Button(String(localized: "Serve from left")) {
                coordinator.chooseDecidingSide(.left)
            }
        }
        .onAppear {
            showServeSidePrompt = coordinator.needsDecidingSideChoice
        }
        .onChange(of: coordinator.needsDecidingSideChoice) { _, needs in
            showServeSidePrompt = needs
        }
    }

    private func liveControlButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.white.opacity(0.95))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                .frame(width: 31, height: 31)
                .background(.black.opacity(0.5), in: Circle())
                .overlay {
                    Circle()
                        .stroke(.black.opacity(0.6), lineWidth: 0.5)
                }
        }
        .buttonStyle(.plain)
    }

    private var courtOptionsEdgeZone: some View {
        Color.clear
            .frame(width: 28)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .highPriorityGesture(
                DragGesture(minimumDistance: 10)
                    .onEnded { value in
                        guard value.translation.width > 14,
                              abs(value.translation.width) > abs(value.translation.height)
                        else { return }
                        showCourtOptions = true
                    }
            )
            .onTapGesture {
                showCourtOptions = true
            }
            .accessibilityLabel(String(localized: "Team layout options"))
            .accessibilityAddTraits(.isButton)
    }

    private var scoreOverlay: some View {
        VStack(spacing: 3) {
            HStack(spacing: 7) {
                if !state.completedSets.isEmpty {
                    HStack(spacing: 5) {
                        ForEach(Array(state.completedSets.enumerated()), id: \.offset) { _, set in
                            Text(ScoreFormatter.formatSetScore(set))
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }

                Text(ScoreFormatter.currentSetGames(in: state))
                    .font(.caption.weight(.semibold))
            }

            Text(ScoreFormatter.currentGameScore(in: state))
                .font(.system(.title2, design: .rounded).weight(.bold))

            if coordinator.workoutWarning != nil {
                Image(systemName: "heart.slash.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.orange)
                    .accessibilityLabel(String(localized: "Workout not recording"))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .scaleEffect(1.15)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(scoreAccessibilityLabel)
        .allowsHitTesting(false)
    }

    private var scoreAccessibilityLabel: String {
        let completed = state.completedSets.map(ScoreFormatter.formatSetScore(_:)).joined(separator: ", ")
        let currentSet = ScoreFormatter.currentSetGames(in: state)
        let game = ScoreFormatter.currentGameScore(in: state)

        if completed.isEmpty {
            return String(localized: "Set score \(currentSet), game score \(game)")
        }
        return String(localized: "Completed sets \(completed), current set \(currentSet), game score \(game)")
    }

    private func teamZone(
        team: Team,
        playerNames: [String],
        playerSlots: [PlayerSlot],
        fallbackLabel: String
    ) -> some View {
        Button {
            coordinator.addPoint(for: team)
        } label: {
            ZStack {
                teamBackground(for: team)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                GeometryReader { proxy in
                    teamNameRow(playerNames: playerNames, playerSlots: playerSlots, fallbackLabel: fallbackLabel)
                        .padding(.horizontal, 12)
                        .shadow(color: .black.opacity(0.25), radius: 1, y: 1)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .offset(y: teamNameVerticalOffset(for: team, height: proxy.size.height))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: serveAlignment(for: team)) {
                serveIndicator(for: team)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .disabled(state.isMatchOver)
        .accessibilityLabel(
            serveAccessibilityLabel(
                for: team,
                label: fallbackLabel,
                playerNames: playerNames,
                playerSlots: playerSlots
            )
        )
    }

    @ViewBuilder
    private func teamNameRow(playerNames: [String], playerSlots: [PlayerSlot], fallbackLabel: String) -> some View {
        if playerNames.count >= 2, playerSlots.count >= 2 {
            HStack(spacing: 0) {
                playerNameLabel(name: playerNames[0], slot: playerSlots[0])
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 16)

                playerNameLabel(name: playerNames[1], slot: playerSlots[1])
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        } else {
            Text(fallbackLabel)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
    }

    private func playerNameLabel(name: String, slot: PlayerSlot) -> some View {
        let isServing = serve?.servingSlot == slot
        return Text(name)
            .font(.headline.weight(isServing ? .bold : .semibold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, isServing ? 8 : 0)
            .padding(.vertical, isServing ? 3 : 0)
            .background(isServing ? .black.opacity(0.5) : .clear, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(isServing ? palette.serveColor : .clear, lineWidth: 1)
            }
    }

    private func teamNameVerticalOffset(for team: Team, height: CGFloat) -> CGFloat {
        team == .b ? height * 0.05 : 0
    }

    @ViewBuilder
    private func serveIndicator(for team: Team) -> some View {
        if let serve, serve.servingTeam == team {
            switch themeStore.serveIndicatorStyle {
            case .sideLabels:
                Text(serve.side == .right ? "R" : "L")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(palette.serveColor)
                    .kerning(1)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.5), in: Capsule())
                    .overlay {
                        Capsule()
                            .stroke(palette.serveColor, lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.5), radius: 4, y: 2)
                    .padding(team == .a ? .top : .bottom, 8)
                    .padding(.horizontal, 12)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            case .movingBall:
                ServeBallIndicator(atTopEdge: team == .a)
            }
        }
    }

    /// Where the serve triangle sits: the net edge of the serving team's zone,
    /// on the deuce/ad box side (mirrored for the top team).
    private func serveAlignment(for team: Team) -> Alignment {
        let vertical: VerticalAlignment = team == .a ? .top : .bottom
        let onRight = serve?.side == .right
        // The top team faces the other way, so its right box is screen-left.
        let trailing = team == .a ? onRight : !onRight
        let horizontal: HorizontalAlignment = trailing ? .trailing : .leading
        return Alignment(horizontal: horizontal, vertical: vertical)
    }

    private func serveAccessibilityLabel(
        for team: Team,
        label: String,
        playerNames: [String],
        playerSlots: [PlayerSlot]
    ) -> String {
        guard let serve, serve.servingTeam == team else {
            return String(localized: "Point \(label)")
        }
        let side = serve.side == .right
            ? String(localized: "right")
            : String(localized: "left")
        if let slotIndex = playerSlots.firstIndex(of: serve.servingSlot),
           let serverName = playerNames[safe: slotIndex] {
            return String(localized: "Point \(label). \(serverName) serving from the \(side).")
        }
        return String(localized: "Point \(label). Serving from the \(side).")
    }

    private func teamBackground(for team: Team) -> LinearGradient {
        palette.gradient(for: team)
    }
}

private extension Array {
    subscript(safe index: Int?) -> Element? {
        guard let index, indices.contains(index) else { return nil }
        return self[index]
    }
}

#Preview {
    NavigationStack {
        WatchLiveMatchView(
            coordinator: {
                let coordinator = WatchMatchCoordinator(
                    workoutRecorder: NoOpWorkoutRecorder(),
                    syncService: WatchConnectivityPublisher()
                )
                coordinator.session = ScoringSession(rules: .default)
                coordinator.playerSetup = MatchPlayerSetup(
                    sideAPlayer1: .init(name: "Sergiu"),
                    sideAPlayer2: .init(name: "Alex"),
                    sideBPlayer1: .init(name: "Mihai"),
                    sideBPlayer2: .init(name: "Catalin")
                )
                coordinator.phase = .live
                return coordinator
            }()
        )
    }
    .environment(AppThemeStore())
}
