import PadelCore
import SwiftUI

@main
struct PadelNoteWatchApp: App {
    @State private var coordinator = WatchMatchCoordinator(
        workoutRecorder: HealthKitWorkoutRecorder(),
        syncService: WatchConnectivityPublisher()
    )

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                WatchStartView(coordinator: coordinator)
            }
        }
    }
}
