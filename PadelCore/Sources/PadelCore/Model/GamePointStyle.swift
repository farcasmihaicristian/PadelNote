public enum GamePointStyle: String, Codable, Hashable, Sendable {
    /// Classic tennis: deuce → advantage → game.
    case advantage
    /// Sudden death at 40-40 ("punto de oro").
    case goldenPoint
    /// Advantage for the first two deuces; sudden death from the third deuce onward.
    case starPoint
}
