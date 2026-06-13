public struct MatchRules: Codable, Hashable, Sendable {
    /// Sets required to win the match (best-of-3 → 2, best-of-5 → 3).
    public var setsToWin: Int
    public var gamesPerSet: Int
    public var winByTwoGames: Bool
    public var gamePointStyle: GamePointStyle
    public var setTieBreak: TieBreakStyle
    public var finalSetTieBreak: TieBreakStyle

    public init(
        setsToWin: Int = 2,
        gamesPerSet: Int = 6,
        winByTwoGames: Bool = true,
        gamePointStyle: GamePointStyle = .advantage,
        setTieBreak: TieBreakStyle = .classic,
        finalSetTieBreak: TieBreakStyle = .superTieBreak10
    ) {
        self.setsToWin = setsToWin
        self.gamesPerSet = gamesPerSet
        self.winByTwoGames = winByTwoGames
        self.gamePointStyle = gamePointStyle
        self.setTieBreak = setTieBreak
        self.finalSetTieBreak = finalSetTieBreak
    }

    /// Default recreational padel preset (D-03).
    public static let `default` = MatchRules(
        gamePointStyle: .goldenPoint
    )
}
