import PadelCore
import SwiftUI

@main
struct PadelNoteWatchApp: App {
    @State private var coordinator = WatchMatchCoordinator(
        workoutRecorder: HealthKitWorkoutRecorder(),
        syncService: WatchConnectivityPublisher()
    )
    @State private var themeStore = AppThemeStore()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                WatchStartView(coordinator: coordinator)
            }
            .environment(themeStore)
            .tint(themeStore.palette.accent)
            .onAppear {
                coordinator.onThemeChanged = { theme in
                    themeStore.apply(theme)
                }
                coordinator.onServeIndicatorStyleChanged = { style in
                    themeStore.applyServeIndicatorStyle(style)
                }
            }
        }
    }
}
