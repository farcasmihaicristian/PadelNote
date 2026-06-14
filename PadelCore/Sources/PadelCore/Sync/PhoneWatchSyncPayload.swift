import Foundation

/// Phone → Watch application context (default rules + known player names + ME profile).
public struct PhoneWatchSyncPayload: Codable, Sendable, Hashable {
    public var rules: MatchRules
    public var knownPlayerNames: [String]
    public var meProfile: WatchMeProfile?

    public init(
        rules: MatchRules,
        knownPlayerNames: [String] = [],
        meProfile: WatchMeProfile? = nil
    ) {
        self.rules = rules
        self.knownPlayerNames = knownPlayerNames
        self.meProfile = meProfile
    }
}
