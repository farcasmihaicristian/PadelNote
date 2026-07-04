import PadelCore
import SwiftUI

struct WatchLiveMatchOptionsView: View {
    @Bindable var coordinator: WatchMatchCoordinator
    @Binding var isPresented: Bool

    var body: some View {
        List {
            optionButton(
                title: String(localized: "Swap Top Team"),
                subtitle: String(localized: "Swap left and right for the top team.")
            ) {
                coordinator.toggleLeftRightSides(for: .b)
            }

            optionButton(
                title: String(localized: "Swap Bottom Team"),
                subtitle: String(localized: "Swap left and right for the bottom team.")
            ) {
                coordinator.toggleLeftRightSides(for: .a)
            }

            if coordinator.canSwapSides {
                Picker(
                    String(localized: "First serve"),
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
        subtitle: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            action()
            isPresented = false
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .disabled(!coordinator.canSwapSides)
        .accessibilityLabel(title)
    }
}

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
