public enum ScoreFormatter {
  private static let gamePointLabels = ["0", "15", "30", "40"]

  /// Formats a single team's game points (0/15/30/40, Ad, or tie-break digits).
  public static func gamePoints(for team: Team, in state: MatchState) -> String {
    if state.isTieBreak {
      return String(team == .a ? state.tieBreakPointsA : state.tieBreakPointsB)
    }

    if let advantageTeam = state.advantageTeam {
      return advantageTeam == team ? "Ad" : "40"
    }

    let points = team == .a ? state.pointA : state.pointB
    guard points >= 0, points < gamePointLabels.count else { return "0" }
    return gamePointLabels[points]
  }

  /// "40-30" style readout for the current game.
  public static func currentGameScore(in state: MatchState) -> String {
    "\(gamePoints(for: .a, in: state))-\(gamePoints(for: .b, in: state))"
  }

  /// Games in the current set, e.g. "3-2".
  public static func currentSetGames(in state: MatchState) -> String {
    "\(state.gamesA)-\(state.gamesB)"
  }

  /// Completed sets plus the live set, e.g. ["6-4", "3-2"].
  public static func setSummary(in state: MatchState) -> [String] {
    var summary = state.completedSets.map { formatSetScore($0) }
    if !state.isMatchOver || state.gamesA > 0 || state.gamesB > 0 || state.pointA > 0 || state.pointB > 0 || state.isTieBreak {
      summary.append(currentSetGames(in: state))
    }
    return summary
  }

  /// Formats one completed set, including tie-break parenthetical when relevant.
  public static func formatSetScore(_ set: SetScore) -> String {
    var base = "\(set.gamesA)-\(set.gamesB)"
    if let tieBreakA = set.tieBreakA, let tieBreakB = set.tieBreakB {
      base += " (\(tieBreakA)-\(tieBreakB))"
    }
    return base
  }

  /// Full match readout for UI, e.g. "6-4 3-2 40-30".
  public static func matchScoreLine(in state: MatchState) -> String {
    var parts = state.completedSets.map { formatSetScore($0) }
    if !state.isMatchOver {
      parts.append("\(currentSetGames(in: state)) \(currentGameScore(in: state))")
    }
    return parts.joined(separator: " ")
  }
}
