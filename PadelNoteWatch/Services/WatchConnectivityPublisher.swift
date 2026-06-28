import Foundation
import PadelCore
import WatchConnectivity

@MainActor
final class WatchConnectivityPublisher: NSObject, MatchSyncPublishing {
    private let session = WCSession.isSupported() ? WCSession.default : nil
    private var pendingLiveScore: LiveScoreSnapshot?
    /// Completed matches currently handed to `transferUserInfo` but not yet
    /// confirmed delivered, so a flush doesn't queue the same transfer twice.
    private var inFlightTransfers: Set<UUID> = []

    var onPhoneContextUpdate: ((PhoneWatchSyncPayload) -> Void)?

    func activate() {
        guard let session else { return }
        session.delegate = self
        if session.activationState != .activated {
            session.activate()
        } else {
            flushPending(session: session)
        }
    }

    func publishLiveScore(_ snapshot: LiveScoreSnapshot) {
        guard let session else { return }
        pendingLiveScore = snapshot
        guard session.activationState == .activated else { return }
        sendLiveScore(snapshot, session: session)
        pendingLiveScore = nil
    }

    func publishSessionEnded(matchID: UUID) {
        publishLiveScore(.sessionEnded(matchID: matchID))
    }

    func publishPointLog(_ payload: MatchTransferPayload) {}

    func publishCompletedMatch(_ payload: MatchTransferPayload) {
        // Persist first so the match survives even if the session isn't ready or
        // the app is killed before delivery; cleared once handed to WatchConnectivity.
        WatchMatchStore.addPendingCompletedMatch(payload)
        guard let session, session.activationState == .activated else { return }
        sendCompletedMatch(payload, session: session)
    }

    private func sendLiveScore(_ snapshot: LiveScoreSnapshot, session: WCSession) {
        let payload = SyncPayloadCodec.encodeLiveScore(snapshot)
        // Application context is the durable, coalescing path the phone reads;
        // sendMessage is a best-effort low-latency nudge while reachable.
        try? session.updateApplicationContext(payload)
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { error in
                #if DEBUG
                print("PadelNote: live-score sendMessage failed: \(error.localizedDescription)")
                #endif
            }
        }
    }

    private func sendCompletedMatch(_ payload: MatchTransferPayload, session: WCSession) {
        let encoded = SyncPayloadCodec.encodeCompletedMatch(payload)
        // Guard against an encode failure leaving a malformed payload queued.
        guard SyncPayloadCodec.hasSyncPayload(encoded) else { return }
        // Don't re-queue a transfer that's already awaiting delivery.
        guard inFlightTransfers.insert(payload.id).inserted else { return }
        session.transferUserInfo(encoded)
        // The pending entry is only removed once `didFinish` confirms delivery,
        // so a failed transfer is retried on the next flush.
    }

    private func flushPending(session: WCSession) {
        if let pendingLiveScore {
            sendLiveScore(pendingLiveScore, session: session)
            self.pendingLiveScore = nil
        }
        for payload in WatchMatchStore.pendingCompletedMatches() {
            sendCompletedMatch(payload, session: session)
        }
        refreshPhoneContext(from: session)
    }

    private func refreshPhoneContext(from session: WCSession) {
        guard let payload = SyncPayloadCodec.decodePhoneContext(from: session.receivedApplicationContext) else { return }
        onPhoneContextUpdate?(payload)
    }

    private func deliverPayload(_ payload: [String: Any]) {
        guard let phoneContext = SyncPayloadCodec.decodePhoneContext(from: payload) else { return }
        onPhoneContextUpdate?(phoneContext)
    }
}

extension WatchConnectivityPublisher: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        guard activationState == .activated else { return }
        Task { @MainActor in
            flushPending(session: session)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in
            deliverPayload(applicationContext)
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didFinish userInfoTransfer: WCSessionUserInfoTransfer,
        error: Error?
    ) {
        let userInfo = userInfoTransfer.userInfo
        Task { @MainActor in
            guard let payload = SyncPayloadCodec.decodeCompletedMatch(from: userInfo) else { return }
            inFlightTransfers.remove(payload.id)
            if error == nil {
                // Delivery confirmed — safe to drop the local safety copy.
                WatchMatchStore.removePendingCompletedMatch(id: payload.id)
            }
            #if DEBUG
            if let error {
                print("PadelNote: completed-match transfer failed, will retry: \(error.localizedDescription)")
            }
            #endif
        }
    }
}
