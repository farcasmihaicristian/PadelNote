import Foundation
import PadelCore
import WatchConnectivity

@MainActor
final class PhoneConnectivityListener: NSObject, MatchSyncListening {
    var onLiveScoreUpdate: ((LiveScoreSnapshot) -> Void)?
    var onMatchReceived: ((MatchTransferPayload) -> Void)?

    private let session = WCSession.isSupported() ? WCSession.default : nil

    func activate() {
        guard let session else { return }
        session.delegate = self
        session.activate()
    }

    private func deliverApplicationContext(_ applicationContext: [String: Any]) {
        if let snapshot = SyncPayloadCodec.decodeLiveScore(from: applicationContext) {
            onLiveScoreUpdate?(snapshot)
        }
    }

    private func deliverUserInfo(_ userInfo: [String: Any]) {
        if let payload = SyncPayloadCodec.decodeCompletedMatch(from: userInfo) {
            onMatchReceived?(payload)
        }
    }
}

extension PhoneConnectivityListener: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            deliverApplicationContext(session.receivedApplicationContext)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in
            deliverApplicationContext(applicationContext)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        Task { @MainActor in
            deliverUserInfo(userInfo)
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
}
