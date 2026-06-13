import PadelCore
import SwiftUI

struct WatchLiveMatchView: View {
    @Bindable var coordinator: WatchMatchCoordinator
    @State private var crownValue = 0.0
    @State private var showEndConfirmation = false

    private var state: MatchState {
        coordinator.currentState ?? ScoringEngine.replay(events: [], rules: coordinator.rules)
    }

    var body: some View {
        VStack(spacing: 0) {
            teamZone(team: .a, label: String(localized: "Team A"))

            scoreStrip

            teamZone(team: .b, label: String(localized: "Team B"))
        }
        .ignoresSafeArea(edges: .horizontal)
        .navigationTitle(String(localized: "Live"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(String(localized: "Undo")) {
                    coordinator.undo()
                }
                .disabled(coordinator.session?.events.isEmpty ?? true)
                .accessibilityLabel(String(localized: "Undo last point"))
            }

            ToolbarItem(placement: .topBarLeading) {
                Button(String(localized: "End")) {
                    showEndConfirmation = true
                }
                .disabled(coordinator.session?.events.isEmpty ?? true)
                .accessibilityLabel(String(localized: "End match"))
            }
        }
        .focusable(true)
        .digitalCrownRotation(
            $crownValue,
            from: 0,
            through: 100,
            by: 1,
            sensitivity: .medium,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
        .onChange(of: crownValue) { _, newValue in
            if newValue > 0 {
                coordinator.undo()
                crownValue = 0
            }
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

    private var scoreStrip: some View {
        VStack(spacing: 2) {
            Text(ScoreFormatter.currentGameScore(in: state))
                .font(.system(.title2, design: .rounded).weight(.bold))
                .accessibilityLabel(String(localized: "Game score \(ScoreFormatter.currentGameScore(in: state))"))

            Text(ScoreFormatter.currentSetGames(in: state))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private func teamZone(team: Team, label: String) -> some View {
        Button {
            coordinator.addPoint(for: team)
        } label: {
            VStack(spacing: 4) {
                Text(label)
                    .font(.headline)
                Text(String(localized: "Point \(label)"))
                    .font(.caption)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(team == .a ? Color.blue.opacity(0.25) : Color.green.opacity(0.25))
        .disabled(state.isMatchOver)
        .accessibilityLabel(String(localized: "Point \(label)"))
    }
}

#Preview {
    let coordinator = WatchMatchCoordinator(
        workoutRecorder: NoOpWorkoutRecorder(),
        syncService: WatchConnectivityPublisher()
    )
    coordinator.session = ScoringSession(rules: .default)
    coordinator.phase = .live
    return WatchLiveMatchView(coordinator: coordinator)
}
