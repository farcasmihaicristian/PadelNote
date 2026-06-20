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
    /// Court lineup per set (index = set number). Captures left/right side
    /// changes made between sets. Empty for matches recorded without per-set
    /// tracking; consumers fall back to the canonical `playerNames`.
    public let setLineups: [MatchPlayerNames]
    /// Serving order per set (index = set number). Empty for matches recorded
    /// without serve tracking.
    public let setServeOrders: [ServeOrder]

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
        distanceMeters: Double? = nil,
        setLineups: [MatchPlayerNames] = [],
        setServeOrders: [ServeOrder] = []
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
        self.setLineups = setLineups
        self.setServeOrders = setServeOrders
    }

    private enum CodingKeys: String, CodingKey {
        case id, startedAt, endedAt, rules, events
        case playerA1Name, playerA2Name, playerB1Name, playerB2Name
        case teamAName, teamBName
        case averageHeartRate, activeEnergyKilocalories, distanceMeters
        case setLineups
        case setServeOrders
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        endedAt = try container.decode(Date.self, forKey: .endedAt)
        rules = try container.decode(MatchRules.self, forKey: .rules)
        events = try container.decode([PointEvent].self, forKey: .events)
        playerA1Name = try container.decodeIfPresent(String.self, forKey: .playerA1Name)
        playerA2Name = try container.decodeIfPresent(String.self, forKey: .playerA2Name)
        playerB1Name = try container.decodeIfPresent(String.self, forKey: .playerB1Name)
        playerB2Name = try container.decodeIfPresent(String.self, forKey: .playerB2Name)
        teamAName = try container.decodeIfPresent(String.self, forKey: .teamAName)
        teamBName = try container.decodeIfPresent(String.self, forKey: .teamBName)
        averageHeartRate = try container.decodeIfPresent(Double.self, forKey: .averageHeartRate)
        activeEnergyKilocalories = try container.decodeIfPresent(Double.self, forKey: .activeEnergyKilocalories)
        distanceMeters = try container.decodeIfPresent(Double.self, forKey: .distanceMeters)
        setLineups = try container.decodeIfPresent([MatchPlayerNames].self, forKey: .setLineups) ?? []
        setServeOrders = try container.decodeIfPresent([ServeOrder].self, forKey: .setServeOrders) ?? []
    }
}
