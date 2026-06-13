import PadelCore
import SwiftData
import SwiftUI

@main
struct PadelNoteApp: App {
    private let modelContainer: ModelContainer

    init() {
        modelContainer = try! ModelContainer(for: Match.self, StoredPointEvent.self)
        #if DEBUG
        SampleMatchData.seed(into: modelContainer.mainContext)
        #endif
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
        }
        .modelContainer(modelContainer)
    }
}
