public struct PointEvent: Codable, Hashable, Sendable {
    public var team: Team

    public init(team: Team) {
        self.team = team
    }
}
