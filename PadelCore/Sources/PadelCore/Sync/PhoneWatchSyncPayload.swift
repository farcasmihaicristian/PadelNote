import Foundation

/// Phone → Watch application context (default rules + known player names + ME profile).
public struct PhoneWatchSyncPayload: Codable, Sendable, Hashable {
    public var rules: MatchRules
    public var knownPlayerNames: [String]
    public var meProfile: WatchMeProfile?
    /// Optional for backward compatibility with payloads sent before the workout
    /// type became configurable. Consumers should fall back to `.default`.
    public var workoutActivity: WorkoutActivityKind?
    /// Optional for backward compatibility with payloads sent before app themes.
    /// Consumers should fall back to `AppThemeCatalog.default`.
    public var themeID: String?

    public init(
        rules: MatchRules,
        knownPlayerNames: [String] = [],
        meProfile: WatchMeProfile? = nil,
        workoutActivity: WorkoutActivityKind? = nil,
        themeID: String? = nil
    ) {
        self.rules = rules
        self.knownPlayerNames = knownPlayerNames
        self.meProfile = meProfile
        self.workoutActivity = workoutActivity
        self.themeID = themeID
    }
}
