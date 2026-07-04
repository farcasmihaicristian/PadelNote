import PadelCore
import SwiftUI

struct WatchLiveMatchOptionsView: View {
    @Bindable var coordinator: WatchMatchCoordinator
    @Binding var isPresented: Bool

    var body: some View {
        List {
            optionButton(
                title: String(localized: "Swap Top Team Players")
            ) {
                coordinator.toggleLeftRightSides(for: .b)
            }

            optionButton(
                title: String(localized: "Swap Bottom Team Players")
            ) {
                coordinator.toggleLeftRightSides(for: .a)
            }

            if coordinator.canSwapSides {
                Picker(
                    String(localized: "Switch Server"),
                    selection: Binding(
                        get: { coordinator.firstServer },
                        set: { coordinator.setFirstServerForCurrentSet($0) }
                    )
                ) {
                    ForEach(PlayerSlot.allCases) { slot in
                        Text(coordinator.serverDisplayName(for: slot)).tag(slot)
                    }
                }
                .accessibilityLabel(String(localized: "Server for this set"))
            }

            if !coordinator.canSwapSides {
                Text(String(localized: "Switch sides or server only at the start of a new set (0-0)."))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(String(localized: "Court"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func optionButton(
        title: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            action()
            isPresented = false
        } label: {
            Text(title)
                .font(.headline)
        }
        .disabled(!coordinator.canSwapSides)
        .accessibilityLabel(title)
    }
}

#if DEBUG
#Preview {
    @Previewable @State var isPresented = true

    NavigationStack {
        WatchLiveMatchOptionsView(
            coordinator: WatchMatchCoordinator(
                workoutRecorder: NoOpWorkoutRecorder(),
                syncService: WatchConnectivityPublisher()
            ),
            isPresented: $isPresented
        )
    }
}
#endif
