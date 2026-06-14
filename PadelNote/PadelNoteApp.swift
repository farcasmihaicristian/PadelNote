import PadelCore
import SwiftData
import SwiftUI

@main
struct PadelNoteApp: App {
    private let modelContainer: ModelContainer
    @State private var syncCoordinator = PhoneSyncCoordinator(syncListener: PhoneConnectivityListener())
    @State private var currentUserStore = CurrentUserStore()
    @State private var showPastMatchLinkDialog = false

    init() {
        modelContainer = try! ModelContainer(
            for: Match.self, StoredPointEvent.self, Player.self, AppUser.self
        )
        #if DEBUG
        SampleMatchData.seed(into: modelContainer.mainContext)
        #endif
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(syncCoordinator)
                .environment(currentUserStore)
                .onAppear {
                    syncCoordinator.activate(modelContext: modelContainer.mainContext)
                    currentUserStore.activate(modelContext: modelContainer.mainContext)
                    PlayerPersistence.backfillUnlinkedMatches(context: modelContainer.mainContext)
                }
                .onChange(of: currentUserStore.pendingPastMatchLinkCount) { _, count in
                    showPastMatchLinkDialog = count > 0
                }
                .confirmationDialog(
                    String(localized: "Link past matches?"),
                    isPresented: $showPastMatchLinkDialog,
                    titleVisibility: .visible
                ) {
                    Button(String(localized: "Link matches")) {
                        currentUserStore.linkPastMatches()
                    }
                    Button(String(localized: "Not now"), role: .cancel) {
                        currentUserStore.dismissPastMatchLinkOffer()
                    }
                } message: {
                    Text(
                        String(
                            localized: "We found \(currentUserStore.pendingPastMatchLinkCount) past matches with your name. Link them to your profile?"
                        )
                    )
                }
        }
        .modelContainer(modelContainer)
    }
}
