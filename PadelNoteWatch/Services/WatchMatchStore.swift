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
    // Reused across the many per-point live-state writes instead of allocating a
    // fresh coder each time.
    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    // MARK: - Live match recovery

    struct LiveMatch: Codable {
        var matchID: UUID
        var startedAt: Date
        var rules: MatchRules
        var events: [PointEvent]
        var playerNames: MatchPlayerNames
        var setLineups: [MatchPlayerNames]
        var setServeOrders: [ServeOrder]

        init(
            matchID: UUID,
            startedAt: Date,
            rules: MatchRules,
            events: [PointEvent],
            playerNames: MatchPlayerNames,
            setLineups: [MatchPlayerNames] = [],
            setServeOrders: [ServeOrder] = []
        ) {
            self.matchID = matchID
            self.startedAt = startedAt
            self.rules = rules
            self.events = events
            self.playerNames = playerNames
            self.setLineups = setLineups
            self.setServeOrders = setServeOrders
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            matchID = try container.decode(UUID.self, forKey: .matchID)
            startedAt = try container.decode(Date.self, forKey: .startedAt)
            rules = try container.decode(MatchRules.self, forKey: .rules)
            events = try container.decode([PointEvent].self, forKey: .events)
            playerNames = try container.decode(MatchPlayerNames.self, forKey: .playerNames)
            setLineups = try container.decodeIfPresent([MatchPlayerNames].self, forKey: .setLineups) ?? []
            setServeOrders = try container.decodeIfPresent([ServeOrder].self, forKey: .setServeOrders) ?? []
        }
    }

    static func saveLiveMatch(_ match: LiveMatch) {
        guard let data = try? encoder.encode(match) else { return }
        defaults.set(data, forKey: liveKey)
    }

    static func loadLiveMatch() -> LiveMatch? {
        guard let data = defaults.data(forKey: liveKey) else { return nil }
        return try? decoder.decode(LiveMatch.self, from: data)
    }

    static func clearLiveMatch() {
        defaults.removeObject(forKey: liveKey)
    }

    // MARK: - Pending completed matches

    static func pendingCompletedMatches() -> [MatchTransferPayload] {
        guard let data = defaults.data(forKey: pendingKey) else { return [] }
        return (try? decoder.decode([MatchTransferPayload].self, from: data)) ?? []
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
        guard let data = try? encoder.encode(pending) else { return }
        defaults.set(data, forKey: pendingKey)
    }
}
