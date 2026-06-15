import Foundation
import PadelCore
import WatchConnectivity

@MainActor
final class WatchConnectivityPublisher: NSObject, MatchSyncPublishing {
    private let session = WCSession.isSupported() ? WCSession.default : nil
    private var pendingLiveScore: LiveScoreSnapshot?

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
        try? session.updateApplicationContext(payload)
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { _ in }
        }
    }

    private func sendCompletedMatch(_ payload: MatchTransferPayload, session: WCSession) {
        let encoded = SyncPayloadCodec.encodeCompletedMatch(payload)
        // Guard against an encode failure leaving a malformed payload queued.
        guard SyncPayloadCodec.hasSyncPayload(encoded) else { return }
        session.transferUserInfo(encoded)
        WatchMatchStore.removePendingCompletedMatch(id: payload.id)
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
}
