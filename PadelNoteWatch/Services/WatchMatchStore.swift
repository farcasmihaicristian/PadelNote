import Foundation
import PadelCore

/// Local on-Watch persistence used for crash recovery and to guarantee a
/// completed match isn't lost if WatchConnectivity can't deliver it immediately.
///
/// Everything is stored in `UserDefaults` as JSON. Two things are tracked:
/// 1. The in-progress live match, written after every point/undo so a crash,
///    force-quit, or battery death mid-match can be recovered on next launch.
/// 2. Completed matches awaiting delivery to the iPhone, kept until the payload
///    has actually been handed to an activated `WCSession`.
enum WatchMatchStore {
    private static let liveKey = "watch.liveMatch.v1"
    private static let pendingKey = "watch.pendingCompletedMatches.v1"

    private static var defaults: UserDefaults { .standard }

    // MARK: - Live match recovery

    struct LiveMatch: Codable {
        var matchID: UUID
        var startedAt: Date
        var rules: MatchRules
        var events: [PointEvent]
        var playerNames: MatchPlayerNames
    }

    static func saveLiveMatch(_ match: LiveMatch) {
        guard let data = try? JSONEncoder().encode(match) else { return }
        defaults.set(data, forKey: liveKey)
    }

    static func loadLiveMatch() -> LiveMatch? {
        guard let data = defaults.data(forKey: liveKey) else { return nil }
        return try? JSONDecoder().decode(LiveMatch.self, from: data)
    }

    static func clearLiveMatch() {
        defaults.removeObject(forKey: liveKey)
    }

    // MARK: - Pending completed matches

    static func pendingCompletedMatches() -> [MatchTransferPayload] {
        guard let data = defaults.data(forKey: pendingKey) else { return [] }
        return (try? JSONDecoder().decode([MatchTransferPayload].self, from: data)) ?? []
    }

    static func addPendingCompletedMatch(_ payload: MatchTransferPayload) {
        var pending = pendingCompletedMatches().filter { $0.id != payload.id }
        pending.append(payload)
        writePending(pending)
    }

    static func removePendingCompletedMatch(id: UUID) {
        let pending = pendingCompletedMatches().filter { $0.id != id }
        writePending(pending)
    }

    private static func writePending(_ pending: [MatchTransferPayload]) {
        if pending.isEmpty {
            defaults.removeObject(forKey: pendingKey)
            return
        }
        guard let data = try? JSONEncoder().encode(pending) else { return }
        defaults.set(data, forKey: pendingKey)
    }
}
