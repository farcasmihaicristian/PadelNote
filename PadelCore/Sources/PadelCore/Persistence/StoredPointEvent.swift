import Foundation
import SwiftData

/// SwiftData persistence for a single recorded point (plan item `PointEvent`).
@Model
public final class StoredPointEvent {
    public var sequence: Int
    public var teamRawValue: String
    public var timestamp: Date

    public var match: Match?

    public init(
        sequence: Int,
        team: Team,
        timestamp: Date = .now,
        match: Match? = nil
    ) {
        self.sequence = sequence
        self.teamRawValue = team.rawValue
        self.timestamp = timestamp
        self.match = match
    }

    public var team: Team {
        Team(rawValue: teamRawValue) ?? .a
    }
}
