public enum TieBreakStyle: String, Codable, Hashable, Sendable {
    /// Play out games until one side leads by two (rare).
    case none
    /// First to 7 points, win by 2, entered at gamesPerSet–gamesPerSet.
    case classic
    /// First to 10 points, win by 2 (often used for the deciding set).
    case superTieBreak10

    public var pointsToWin: Int {
        switch self {
        case .none: 0
        case .classic: 7
        case .superTieBreak10: 10
        }
    }
}
