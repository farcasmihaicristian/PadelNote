import PadelCore
import SwiftData
import SwiftUI

@main
struct PadelNoteApp: App {
    private let modelContainer: ModelContainer
    @State private var syncCoordinator = PhoneSyncCoordinator(syncListener: PhoneConnectivityListener())
    @State private var currentUserStore = CurrentUserStore()
    @State private var themeStore = AppThemeStore()
    @State private var showPastMatchLinkDialog = false

    init() {
        do {
            modelContainer = try ModelContainer(
                for: Match.self, StoredPointEvent.self, Player.self, AppUser.self
            )
        } catch {
            // A failed lightweight migration (likely across evolving test builds) or a
            // corrupt store would otherwise hard-crash on launch. Fall back to an
            // in-memory store so the app still opens; the on-disk data is left intact
            // for a later fix rather than being wiped here.
            assertionFailure("Persistent ModelContainer failed to load: \(error)")
            let schema = Schema([Match.self, StoredPointEvent.self, Player.self, AppUser.self])
            modelContainer = try! ModelContainer(
                for: schema,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
        }
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(syncCoordinator)
                .environment(currentUserStore)
                .environment(themeStore)
                .tint(themeStore.palette.accent)
                .onAppear {
                    syncCoordinator.activate(modelContext: modelContainer.mainContext)
                    currentUserStore.activate(modelContext: modelContainer.mainContext)
                    #if DEBUG
                    // Debug-only: seeds the local store from the bundled sample CSV for a
                    // populated Insights view during development. This is destructive
                    // (replaces all matches on an import-version bump), so it must never
                    // run in Release/TestFlight builds where testers record real matches.
                    HistoryDriveImporter.importIfNeeded(context: modelContainer.mainContext)
                    #endif
                    MatchPersistence.backfillCompletionFlags(context: modelContainer.mainContext)
                    PlayerPersistence.backfillUnlinkedMatches(context: modelContainer.mainContext)
                    syncCoordinator.syncPhoneContextToWatch()
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
