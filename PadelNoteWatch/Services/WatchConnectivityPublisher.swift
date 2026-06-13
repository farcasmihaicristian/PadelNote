import Foundation
import PadelCore
import WatchConnectivity

@MainActor
final class WatchConnectivityPublisher: NSObject, MatchSyncPublishing {
    private let session = WCSession.isSupported() ? WCSession.default : nil

    func activate() {
        guard let session else { return }
        session.delegate = self
        session.activate()
    }

    func publishLiveScore(_ snapshot: LiveScoreSnapshot) {
        guard let session, session.activationState == .activated else { return }
        try? session.updateApplicationContext(SyncPayloadCodec.encodeLiveScore(snapshot))
    }

    func publishPointLog(_ payload: MatchTransferPayload) {
        guard let session, session.activationState == .activated else { return }
        session.transferUserInfo(SyncPayloadCodec.encodePointLog(payload))
    }

    func publishCompletedMatch(_ payload: MatchTransferPayload) {
        guard let session, session.activationState == .activated else { return }
        session.transferUserInfo(SyncPayloadCodec.encodeCompletedMatch(payload))
    }
}

extension WatchConnectivityPublisher: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}
}
