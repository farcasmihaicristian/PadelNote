import Foundation

/// Full match record sent from Watch to iPhone on match completion.
public struct MatchTransferPayload: Codable, Hashable, Sendable {
    public let id: UUID
    public let startedAt: Date
    public let endedAt: Date
    public let rules: MatchRules
    public let events: [PointEvent]
    public let teamAName: String?
    public let teamBName: String?
    public let averageHeartRate: Double?
    public let activeEnergyKilocalories: Double?
    public let distanceMeters: Double?

    public init(
        id: UUID = UUID(),
        startedAt: Date,
        endedAt: Date,
        rules: MatchRules,
        events: [PointEvent],
        teamAName: String?,
        teamBName: String?,
        averageHeartRate: Double? = nil,
        activeEnergyKilocalories: Double? = nil,
        distanceMeters: Double? = nil
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.rules = rules
        self.events = events
        self.teamAName = teamAName?.nilIfEmpty
        self.teamBName = teamBName?.nilIfEmpty
        self.averageHeartRate = averageHeartRate
        self.activeEnergyKilocalories = activeEnergyKilocalories
        self.distanceMeters = distanceMeters
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
