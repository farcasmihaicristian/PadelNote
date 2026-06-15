import PadelCore
import SwiftUI

struct WatchLiveMatchOptionsView: View {
    @Bindable var coordinator: WatchMatchCoordinator
    @Binding var isPresented: Bool

    var body: some View {
        List {
            optionButton(
                title: String(localized: "Change Left/Right — Top"),
                subtitle: String(localized: "Swap left and right for the top pair.")
            ) {
                coordinator.toggleLeftRightSides(for: .b)
            }

            optionButton(
                title: String(localized: "Change Left/Right — Bottom"),
                subtitle: String(localized: "Swap left and right for the bottom pair.")
            ) {
                coordinator.toggleLeftRightSides(for: .a)
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
