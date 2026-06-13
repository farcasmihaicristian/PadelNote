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
    }

    var isWatchMatchLive: Bool {
        guard let liveSnapshot else { return false }
        return !liveSnapshot.isMatchOver
    }

    func activate(modelContext: ModelContext) {
        self.modelContext = modelContext

        syncListener.onLiveScoreUpdate = { [weak self] snapshot in
            self?.liveSnapshot = snapshot
        }

        syncListener.onMatchReceived = { [weak self] payload in
            guard let self, let modelContext = self.modelContext else { return }
            _ = MatchPersistence.saveTransferredMatch(context: modelContext, payload: payload)
            if self.liveSnapshot?.matchID == payload.id {
                self.liveSnapshot = nil
            }
        }

        syncListener.activate()
    }
}
