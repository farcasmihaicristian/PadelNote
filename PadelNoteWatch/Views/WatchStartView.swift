import PadelCore
import SwiftUI

struct WatchStartView: View {
    @Bindable var coordinator: WatchMatchCoordinator
    @State private var showEndConfirmation = false

    var body: some View {
        Group {
            switch coordinator.phase {
            case .idle:
                startContent
            case .live:
                WatchLiveMatchView(coordinator: coordinator)
            case .summary:
                WatchMatchSummaryView(coordinator: coordinator)
            }
        }
        .task {
            await coordinator.prepare()
        }
    }

    private var startContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(String(localized: "PadelNote"))
                    .font(.headline)

                Text(MatchRulesPreferences.summary(for: coordinator.rules))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if coordinator.healthAuthDenied {
                    Text(String(localized: "Health access denied. You can still score, but workouts won't be saved to Apple Health."))
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }

                Button {
                    Task { await coordinator.startMatch() }
                } label: {
                    if coordinator.isStarting {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text(String(localized: "Start"))
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(coordinator.isStarting)
                .accessibilityLabel(String(localized: "Start match"))
            }
            .padding(.horizontal, 4)
        }
    }
}

#Preview {
    WatchStartView(
        coordinator: WatchMatchCoordinator(
            workoutRecorder: NoOpWorkoutRecorder(),
            syncService: WatchConnectivityPublisher()
        )
    )
}
