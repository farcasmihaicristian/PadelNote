import Foundation
import PadelCore

@MainActor
protocol MatchSyncPublishing: AnyObject {
    func activate()
    func publishLiveScore(_ snapshot: LiveScoreSnapshot)
    func publishSessionEnded(matchID: UUID)
    func publishPointLog(_ payload: MatchTransferPayload)
    func publishCompletedMatch(_ payload: MatchTransferPayload)
}
