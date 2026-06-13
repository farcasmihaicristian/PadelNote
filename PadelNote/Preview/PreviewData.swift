import PadelCore
import SwiftData
import SwiftUI

@MainActor
enum PreviewData {
    static let container: ModelContainer = {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: Match.self, StoredPointEvent.self,
            configurations: configuration
        )
        SampleMatchData.seed(into: container.mainContext)
        return container
    }()
}
