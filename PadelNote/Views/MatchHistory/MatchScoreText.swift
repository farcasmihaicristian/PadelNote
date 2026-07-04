import PadelCore
import SwiftUI

/// Builds the final-score readout, with completed sets in the default color and
/// any unfinished (started-but-not-completed) set appended in red.
enum MatchScoreText {
    /// The visible score and its VoiceOver label, computed together so the
    /// (potentially replay-bearing) `inProgressSetSummary` is evaluated once.
    struct Rendered {
        let text: Text
        let accessibilityLabel: String
    }

    static func rendered(for match: Match) -> Rendered {
        let completed = match.scoreSummary
        let partial = match.inProgressSetSummary

        guard let partial else {
            return Rendered(text: Text(completed), accessibilityLabel: completed)
        }

        let separator = completed.isEmpty ? "" : " "
        let text = Text(completed) + Text("\(separator)\(partial)").foregroundStyle(.red)
        let label = completed.isEmpty
            ? String(localized: "unfinished set \(partial)")
            : String(localized: "\(completed), unfinished set \(partial)")
        return Rendered(text: text, accessibilityLabel: label)
    }

    static func make(for match: Match) -> Text {
        rendered(for: match).text
    }

    static func accessibilityLabel(for match: Match) -> String {
        rendered(for: match).accessibilityLabel
    }
}
