import Foundation
import PadelCore
import WatchConnectivity

@MainActor
final class PhoneConnectivityListener: NSObject, MatchSyncListening {
    var onLiveScoreUpdate: ((LiveScoreSnapshot) -> Void)?
    var onPointLogUpdate: ((MatchTransferPayload) -> Void)?
    var onMatchReceived: ((MatchTransferPayload) -> Void)?

    private let session = WCSession.isSupported() ? WCSession.default : nil

    func activate() {
        guard let session else { return }
        if session.delegate == nil {
            session.delegate = self
        }
        session.activate()
    }

    private func deliverPayload(_ payload: [String: Any]) {
        guard SyncPayloadCodec.hasSyncPayload(payload) else { return }

        if let snapshot = SyncPayloadCodec.decodeLiveScore(from: payload) {
            onLiveScoreUpdate?(snapshot)
            return
        }

        if let match = SyncPayloadCodec.decodeCompletedMatch(from: payload) {
            onMatchReceived?(match)
        }
    }

    private func deliverUserInfo(_ userInfo: [String: Any]) {
        if let payload = SyncPayloadCodec.decodeCompletedMatch(from: userInfo) {
            onMatchReceived?(payload)
            return
        }
        if let payload = SyncPayloadCodec.decodePointLog(from: userInfo) {
            onPointLogUpdate?(payload)
        }
    }

    private func refreshFromSession(_ session: WCSession) {
        deliverPayload(session.receivedApplicationContext)
    }
}

extension PhoneConnectivityListener: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        guard activationState == .activated else { return }
        Task { @MainActor in
            refreshFromSession(session)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in
            deliverPayload(applicationContext)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            deliverPayload(message)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        Task { @MainActor in
            deliverUserInfo(userInfo)
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            refreshFromSession(session)
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
}
