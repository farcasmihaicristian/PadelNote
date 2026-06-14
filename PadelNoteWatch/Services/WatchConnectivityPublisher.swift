import Foundation
import PadelCore
import WatchConnectivity

@MainActor
final class WatchConnectivityPublisher: NSObject, MatchSyncPublishing {
    private let session = WCSession.isSupported() ? WCSession.default : nil
    private var pendingLiveScore: LiveScoreSnapshot?
    private var pendingCompletedMatch: MatchTransferPayload?

    var onDefaultRulesUpdate: ((MatchRules) -> Void)?

    func activate() {
        guard let session else { return }
        session.delegate = self
        if session.activationState != .activated {
            session.activate()
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
        guard let session else { return }
        pendingCompletedMatch = payload
        guard session.activationState == .activated else { return }
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
        session.transferUserInfo(encoded)
        pendingCompletedMatch = nil
    }

    private func flushPending(session: WCSession) {
        if let pendingLiveScore {
            sendLiveScore(pendingLiveScore, session: session)
            self.pendingLiveScore = nil
        }
        if let pendingCompletedMatch {
            sendCompletedMatch(pendingCompletedMatch, session: session)
        }
        refreshDefaultRules(from: session)
    }

    private func refreshDefaultRules(from session: WCSession) {
        guard let rules = SyncPayloadCodec.decodeDefaultRules(from: session.receivedApplicationContext) else { return }
        onDefaultRulesUpdate?(rules)
    }

    private func deliverPayload(_ payload: [String: Any]) {
        guard let rules = SyncPayloadCodec.decodeDefaultRules(from: payload) else { return }
        onDefaultRulesUpdate?(rules)
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
