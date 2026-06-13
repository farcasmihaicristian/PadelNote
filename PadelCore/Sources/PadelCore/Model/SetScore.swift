public struct SetScore: Codable, Hashable, Sendable {
    public var gamesA: Int
    public var gamesB: Int
    /// Tie-break points for team A when the set was decided by a tie-break.
    public var tieBreakA: Int?
    public var tieBreakB: Int?

    public init(gamesA: Int, gamesB: Int, tieBreakA: Int? = nil, tieBreakB: Int? = nil) {
        self.gamesA = gamesA
        self.gamesB = gamesB
        self.tieBreakA = tieBreakA
        self.tieBreakB = tieBreakB
    }

    public var winner: Team? {
        if gamesA > gamesB { return .a }
        if gamesB > gamesA { return .b }
        return nil
    }
}
