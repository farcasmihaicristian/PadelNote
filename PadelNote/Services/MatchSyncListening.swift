import Foundation
import PadelCore

@MainActor
protocol MatchSyncListening: AnyObject {
    var onLiveScoreUpdate: ((LiveScoreSnapshot) -> Void)? { get set }
    var onPointLogUpdate: ((MatchTransferPayload) -> Void)? { get set }
    var onMatchReceived: ((MatchTransferPayload) -> Void)? { get set }

    func activate()
    func refresh() async
}
