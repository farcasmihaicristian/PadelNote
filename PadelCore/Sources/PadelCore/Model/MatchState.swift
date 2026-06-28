public struct MatchState: Codable, Hashable, Sendable {
    public var rules: MatchRules
    /// Game points for team A, encoded as 0…3 (0/15/30/40).
    public var pointA: Int
    public var pointB: Int
    public var gamesA: Int
    public var gamesB: Int
    public var completedSets: [SetScore]
    public var isTieBreak: Bool
    public var tieBreakPointsA: Int
    public var tieBreakPointsB: Int
    /// Non-nil when one side holds advantage after deuce (advantage / star-point styles).
    public var advantageTeam: Team?
    /// Number of times the game has returned to 40-40 (used by star point).
    public var deuceCount: Int
    public var isMatchOver: Bool
    public var winner: Team?

    public init(rules: MatchRules) {
        self.rules = rules
        self.pointA = 0
        self.pointB = 0
        self.gamesA = 0
        self.gamesB = 0
        self.completedSets = []
        self.isTieBreak = false
        self.tieBreakPointsA = 0
        self.tieBreakPointsB = 0
        self.advantageTeam = nil
        self.deuceCount = 0
        self.isMatchOver = false
        self.winner = nil
    }

    public var setsWonA: Int {
        completedSets.filter { $0.winner == .a }.count
    }

    public var setsWonB: Int {
        completedSets.filter { $0.winner == .b }.count
    }

    public var isDecidingSet: Bool {
        setsWonA == rules.setsToWin - 1 && setsWonB == rules.setsToWin - 1
    }

    /// True at 40-40 with no advantage held (the classic deuce position).
    public var isAtDeuce: Bool {
        !isTieBreak && pointA == 3 && pointB == 3 && advantageTeam == nil
    }

    /// True when the next point decides the game outright: golden point, or the
    /// third deuce under star-point rules. Single source of truth shared by the
    /// scoring display (`ScoreFormatter`), serve side (`ServeEngine`), and
    /// statistics (`MatchStatistics`).
    public var isSuddenDeathPoint: Bool {
        guard isAtDeuce else { return false }
        switch rules.gamePointStyle {
        case .goldenPoint: return true
        case .starPoint: return deuceCount >= 3
        case .advantage: return false
        }
    }
}
