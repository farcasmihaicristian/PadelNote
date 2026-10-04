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
        WatchStartFormLayout {
            Section {
                Picker(String(localized: "Sets"), selection: $coordinator.bestOfSets) {
                    Text(String(localized: "Best of 1")).tag(1)
                    Text(String(localized: "Best of 3")).tag(3)
                    Text(String(localized: "Best of 5")).tag(5)
                }
                .watchStartPickerRow()
                .accessibilityLabel(String(localized: "Number of sets"))

                Picker(String(localized: "Deuce rule"), selection: $coordinator.gamePointStyle) {
                    Text(String(localized: "Golden point")).tag(GamePointStyle.goldenPoint)
                    Text(String(localized: "Advantage")).tag(GamePointStyle.advantage)
                    Text(String(localized: "Star point")).tag(GamePointStyle.starPoint)
                }
                .watchStartPickerRow()
                .accessibilityLabel(String(localized: "Deuce rule"))
            }

            Section(String(localized: "Players (optional)")) {
                WatchPlayerSlotPicker(
                    title: String(localized: "Bottom · Right"),
                    slot: .sideAPlayer1,
                    coordinator: coordinator
                )
                WatchPlayerSlotPicker(
                    title: String(localized: "Bottom · Left"),
                    slot: .sideAPlayer2,
                    coordinator: coordinator
                )
                WatchPlayerSlotPicker(
                    title: String(localized: "Top · Right"),
                    slot: .sideBPlayer1,
                    coordinator: coordinator
                )
                WatchPlayerSlotPicker(
                    title: String(localized: "Top · Left"),
                    slot: .sideBPlayer2,
                    coordinator: coordinator
                )
            }

            Section {
                Picker(String(localized: "First serve"), selection: $coordinator.firstServer) {
                    ForEach(PlayerSlot.allCases) { slot in
                        Text(coordinator.serverDisplayName(for: slot)).tag(slot)
                    }
                }
                .watchStartPickerRow()
                .accessibilityLabel(String(localized: "First server"))
            }

            if coordinator.healthAuthDenied {
                Section {
                    Text(String(localized: "Health access denied. You can still score, but workouts won't be saved to Apple Health."))
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }

            if coordinator.pendingSyncCount > 0 {
                Section {
                    Label(
                        String(localized: "\(coordinator.pendingSyncCount) match(es) waiting to sync to iPhone"),
                        systemImage: "arrow.triangle.2.circlepath"
                    )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }

            Section {
                Button {
                    coordinator.startMatch()
                } label: {
                    Text(String(localized: "Start"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .watchStartPrimaryButton()
                .accessibilityLabel(String(localized: "Start match"))
            }
        }
        .navigationTitle(String(localized: "PadelNote Watch"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

#if DEBUG
#Preview {
    WatchStartView(
        coordinator: WatchMatchCoordinator(
            workoutRecorder: NoOpWorkoutRecorder(),
            syncService: WatchConnectivityPublisher()
        )
    )
}
#endif
