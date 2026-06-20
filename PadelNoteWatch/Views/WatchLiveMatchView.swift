import PadelCore
import SwiftUI

struct WatchLiveMatchView: View {
    @Bindable var coordinator: WatchMatchCoordinator
    @State private var showEndConfirmation = false
    @State private var showCourtOptions = false
    @State private var showServeSidePrompt = false

    private var state: MatchState {
        coordinator.currentState ?? ScoringEngine.replay(events: [], rules: coordinator.rules)
    }

    private var serve: ServeContext? {
        coordinator.currentServe
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                teamZone(
                    team: .b,
                    playerNames: coordinator.activePlayerNames.playersInCourtDisplayOrder(for: .b),
                    fallbackLabel: coordinator.displaySideLabel(for: .b)
                )

                teamZone(
                    team: .a,
                    playerNames: coordinator.activePlayerNames.playersInCourtDisplayOrder(for: .a),
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
            Button(String(localized: "Receive right")) {
                coordinator.chooseDecidingSide(.right)
            }
            Button(String(localized: "Receive left")) {
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
        Button(title, action: action)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(.white.opacity(0.95))
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(.black.opacity(0.5), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(.black.opacity(0.6), lineWidth: 0.5)
            }
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

    private func teamZone(team: Team, playerNames: [String], fallbackLabel: String) -> some View {
        Button {
            coordinator.addPoint(for: team)
        } label: {
            ZStack {
                teamBackground(for: team)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                teamNameRow(playerNames: playerNames, fallbackLabel: fallbackLabel)
                    .padding(.horizontal, 12)
                    .shadow(color: .black.opacity(0.25), radius: 1, y: 1)
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
        .accessibilityLabel(serveAccessibilityLabel(for: team, label: fallbackLabel))
    }

    @ViewBuilder
    private func teamNameRow(playerNames: [String], fallbackLabel: String) -> some View {
        if playerNames.count >= 2 {
            HStack(spacing: 0) {
                Text(playerNames[0])
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 16)

                Text(playerNames[1])
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
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

    @ViewBuilder
    private func serveIndicator(for team: Team) -> some View {
        if let serve, serve.servingTeam == team {
            Image(systemName: team == .a ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.orange)
                .shadow(color: .black.opacity(0.35), radius: 1, y: 0.5)
                .padding(team == .a ? .top : .bottom, 5)
                .padding(.horizontal, 10)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
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

    private func serveAccessibilityLabel(for team: Team, label: String) -> String {
        guard let serve, serve.servingTeam == team else {
            return String(localized: "Point \(label)")
        }
        let side = serve.side == .right
            ? String(localized: "right")
            : String(localized: "left")
        return String(localized: "Point \(label). Serving from the \(side).")
    }

    private func teamBackground(for team: Team) -> Color {
        switch team {
        case .a:
            Color(red: 0.20, green: 0.36, blue: 0.55)
        case .b:
            Color(red: 0.18, green: 0.44, blue: 0.30)
        }
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
}
