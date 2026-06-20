import Foundation
import Observation
import PadelCore
import SwiftData

@Observable
@MainActor
final class PhoneSyncCoordinator {
    var liveSnapshot: LiveScoreSnapshot?

    private let syncListener: any MatchSyncListening
    private var modelContext: ModelContext?

    init(syncListener: any MatchSyncListening) {
        self.syncListener = syncListener
        configureHandlers()
    }

    var isWatchMatchLive: Bool {
        liveSnapshot?.isVisibleOnPhone == true
    }

    func activate(modelContext: ModelContext) {
        self.modelContext = modelContext
        syncListener.activate()
        syncPhoneContextToWatch()
    }

    func refresh() async {
        await syncListener.refresh()
        modelContext?.processPendingChanges()
        syncPhoneContextToWatch()
    }

    func syncDefaultRulesToWatch() {
        syncPhoneContextToWatch()
    }

    func syncPhoneContextToWatch() {
        guard let listener = syncListener as? PhoneConnectivityListener,
              let modelContext
        else { return }

        let payload = PhoneWatchSyncPayload(
            rules: MatchRulesPreferences.load(),
            knownPlayerNames: PlayerPersistence.distinctDisplayNames(context: modelContext),
            meProfile: PlayerPersistence.watchMeProfile(context: modelContext),
            workoutActivity: WorkoutActivityPreferences.load()
        )
        listener.publishPhoneContext(payload)
    }

    private func configureHandlers() {
        syncListener.onLiveScoreUpdate = { [weak self] snapshot in
            self?.liveSnapshot = snapshot.isVisibleOnPhone ? snapshot : nil
        }

        syncListener.onPointLogUpdate = { _ in }

        syncListener.onMatchReceived = { [weak self] payload in
            guard let self, let modelContext = self.modelContext else { return }
            _ = MatchPersistence.saveTransferredMatch(context: modelContext, payload: payload)
            if self.liveSnapshot?.matchID == payload.id {
                self.liveSnapshot = nil
            }
            self.syncPhoneContextToWatch()
        }
    }
}
