import PadelCore
import SwiftUI

struct WatchLiveMatchView: View {
    @Bindable var coordinator: WatchMatchCoordinator
    @State private var showEndConfirmation = false
    @State private var showCourtOptions = false

    private var state: MatchState {
        coordinator.currentState ?? ScoringEngine.replay(events: [], rules: coordinator.rules)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VStack(spacing: 0) {
                    teamZone(
                        team: .b,
                        label: coordinator.displaySideLabel(for: .b),
                        height: geometry.size.height / 2
                    )

                    teamZone(
                        team: .a,
                        label: coordinator.displaySideLabel(for: .a),
                        height: geometry.size.height / 2
                    )
                }

                scoreOverlay

                HStack(spacing: 0) {
                    courtOptionsEdgeZone(height: geometry.size.height)
                    Spacer(minLength: 0)
                }
            }
        }
        .ignoresSafeArea(edges: .horizontal)
        .navigationTitle(String(localized: "Live"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(String(localized: "End")) {
                    showEndConfirmation = true
                }
                .disabled(coordinator.session?.events.isEmpty ?? true)
                .accessibilityLabel(String(localized: "End match"))
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button(String(localized: "Undo")) {
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
    }

    private func courtOptionsEdgeZone(height: CGFloat) -> some View {
        Color.clear
            .frame(width: 28, height: height)
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
        VStack(spacing: 2) {
            HStack(spacing: 6) {
                if !state.completedSets.isEmpty {
                    HStack(spacing: 4) {
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
                .font(.system(.title3, design: .rounded).weight(.bold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(scoreAccessibilityLabel)
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

    private func teamZone(team: Team, label: String, height: CGFloat) -> some View {
        Button {
            coordinator.addPoint(for: team)
        } label: {
            Text(label)
                .font(.headline)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .background(team == .a ? Color.blue.opacity(0.32) : Color.green.opacity(0.32))
        .disabled(state.isMatchOver)
        .accessibilityLabel(String(localized: "Point \(label)"))
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
