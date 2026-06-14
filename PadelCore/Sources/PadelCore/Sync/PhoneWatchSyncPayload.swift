import Foundation

/// Phone → Watch application context (default rules + known player names).
public struct PhoneWatchSyncPayload: Codable, Sendable, Hashable {
    public var rules: MatchRules
    public var knownPlayerNames: [String]

    public init(rules: MatchRules, knownPlayerNames: [String] = []) {
        self.rules = rules
        self.knownPlayerNames = knownPlayerNames
    }
}
