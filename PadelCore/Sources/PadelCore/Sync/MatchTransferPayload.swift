import Foundation

/// Full match record sent from Watch to iPhone on match completion.
public struct MatchTransferPayload: Codable, Hashable, Sendable {
    public let id: UUID
    public let startedAt: Date
    public let endedAt: Date
    public let rules: MatchRules
    public let events: [PointEvent]
    public let playerA1Name: String?
    public let playerA2Name: String?
    public let playerB1Name: String?
    public let playerB2Name: String?
    public let teamAName: String?
    public let teamBName: String?
    public let averageHeartRate: Double?
    public let activeEnergyKilocalories: Double?
    public let distanceMeters: Double?

    public var playerNames: MatchPlayerNames {
        MatchPlayerNames(
            playerA1Name: playerA1Name,
            playerA2Name: playerA2Name,
            playerB1Name: playerB1Name,
            playerB2Name: playerB2Name,
            teamAName: teamAName,
            teamBName: teamBName
        )
    }

    public init(
        id: UUID = UUID(),
        startedAt: Date,
        endedAt: Date,
        rules: MatchRules,
        events: [PointEvent],
        playerNames: MatchPlayerNames = .empty,
        averageHeartRate: Double? = nil,
        activeEnergyKilocalories: Double? = nil,
        distanceMeters: Double? = nil
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.rules = rules
        self.events = events
        self.playerA1Name = playerNames.playerA1Name
        self.playerA2Name = playerNames.playerA2Name
        self.playerB1Name = playerNames.playerB1Name
        self.playerB2Name = playerNames.playerB2Name
        self.teamAName = playerNames.teamAName
        self.teamBName = playerNames.teamBName
        self.averageHeartRate = averageHeartRate
        self.activeEnergyKilocalories = activeEnergyKilocalories
        self.distanceMeters = distanceMeters
    }
}
