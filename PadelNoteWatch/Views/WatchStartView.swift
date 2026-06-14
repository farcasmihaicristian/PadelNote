import PadelCore
import SwiftUI

struct WatchStartView: View {
    @Bindable var coordinator: WatchMatchCoordinator

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
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "PadelNote"))
                    .font(.headline)

                Group {
                    Picker(String(localized: "Sets"), selection: $coordinator.bestOfSets) {
                        Text(String(localized: "Best of 1")).tag(1)
                        Text(String(localized: "Best of 3")).tag(3)
                        Text(String(localized: "Best of 5")).tag(5)
                    }
                    .accessibilityLabel(String(localized: "Number of sets"))

                    Picker(String(localized: "Deuce rule"), selection: $coordinator.gamePointStyle) {
                        Text(String(localized: "Golden point")).tag(GamePointStyle.goldenPoint)
                        Text(String(localized: "Advantage")).tag(GamePointStyle.advantage)
                        Text(String(localized: "Star point")).tag(GamePointStyle.starPoint)
                    }
                    .accessibilityLabel(String(localized: "Deuce rule"))
                }

                Text(String(localized: "Players (optional)"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)

                WatchPlayerSlotPicker(
                    title: String(localized: "Side A player 1"),
                    slot: .sideAPlayer1,
                    coordinator: coordinator
                )
                WatchPlayerSlotPicker(
                    title: String(localized: "Side A player 2"),
                    slot: .sideAPlayer2,
                    coordinator: coordinator
                )
                WatchPlayerSlotPicker(
                    title: String(localized: "Side B player 1"),
                    slot: .sideBPlayer1,
                    coordinator: coordinator
                )
                WatchPlayerSlotPicker(
                    title: String(localized: "Side B player 2"),
                    slot: .sideBPlayer2,
                    coordinator: coordinator
                )

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
                .padding(.top, 4)
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
