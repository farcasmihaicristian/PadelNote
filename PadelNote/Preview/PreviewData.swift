#if DEBUG
import PadelCore
import SwiftData
import SwiftUI

@MainActor
enum PreviewData {
    static let container: ModelContainer = {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: Match.self, StoredPointEvent.self, Player.self, AppUser.self,
            configurations: configuration
        )
        try? HistoryDriveImporter.replaceAllHistory(context: container.mainContext)
        return container
    }()
}
#endif
