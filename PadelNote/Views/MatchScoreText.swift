import PadelCore
import SwiftUI

/// Builds the final-score readout, with completed sets in the default color and
/// any unfinished (started-but-not-completed) set appended in red.
enum MatchScoreText {
    static func make(for match: Match) -> Text {
        let completed = match.scoreSummary

        guard let partial = match.inProgressSetSummary else {
            return Text(completed)
        }

        let separator = completed.isEmpty ? "" : " "
        return Text(completed) + Text("\(separator)\(partial)").foregroundStyle(.red)
    }

    static func accessibilityLabel(for match: Match) -> String {
        guard let partial = match.inProgressSetSummary else {
            return match.scoreSummary
        }
        if match.scoreSummary.isEmpty {
            return String(localized: "unfinished set \(partial)")
        }
        return String(localized: "\(match.scoreSummary), unfinished set \(partial)")
    }
}
