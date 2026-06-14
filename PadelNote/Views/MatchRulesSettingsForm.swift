import PadelCore
import SwiftUI

struct MatchRulesSettingsForm: View {
    @Binding var bestOfSets: Int
    @Binding var gamePointStyle: GamePointStyle
    @Binding var setTieBreak: TieBreakStyle
    @Binding var finalSetTieBreak: TieBreakStyle

    var body: some View {
        Section(String(localized: "Match format")) {
            Picker(String(localized: "Sets"), selection: $bestOfSets) {
                Text(String(localized: "Best of 1")).tag(1)
                Text(String(localized: "Best of 3")).tag(3)
                Text(String(localized: "Best of 5")).tag(5)
            }
            .accessibilityLabel(String(localized: "Number of sets"))

            Picker(String(localized: "Deuce rule"), selection: $gamePointStyle) {
                Text(String(localized: "Golden point")).tag(GamePointStyle.goldenPoint)
                Text(String(localized: "Advantage")).tag(GamePointStyle.advantage)
                Text(String(localized: "Star point")).tag(GamePointStyle.starPoint)
            }
            .accessibilityLabel(String(localized: "Deuce rule"))
        }

        if let explanation = ruleExplanation {
            Section(String(localized: "How this rule works")) {
                Text(explanation)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }

        Section(String(localized: "Tie-break")) {
            Picker(String(localized: "At 6–6"), selection: $setTieBreak) {
                Text(String(localized: "Classic (to 7)")).tag(TieBreakStyle.classic)
                Text(String(localized: "Play out games")).tag(TieBreakStyle.none)
            }

            Picker(String(localized: "Deciding set"), selection: $finalSetTieBreak) {
                Text(String(localized: "Super tie-break (to 10)")).tag(TieBreakStyle.superTieBreak10)
                Text(String(localized: "Classic (to 7)")).tag(TieBreakStyle.classic)
                Text(String(localized: "Play out games")).tag(TieBreakStyle.none)
            }
        }
    }

    private var ruleExplanation: String? {
        switch gamePointStyle {
        case .goldenPoint:
            String(localized: "At 40-40, the next point wins the game — no advantage games.")
        case .advantage:
            String(localized: "Classic tennis rules: after deuce, a team must win two points in a row.")
        case .starPoint:
            String(localized: "Advantage rules apply for the first two deuces; the third deuce is sudden death.")
        }
    }
}

extension MatchRulesSettingsForm {
    static func bestOfSets(from rules: MatchRules) -> Int {
        MatchRulesPreferences.bestOfSets(from: rules)
    }

    static func makeRules(
        bestOfSets: Int,
        gamePointStyle: GamePointStyle,
        setTieBreak: TieBreakStyle,
        finalSetTieBreak: TieBreakStyle
    ) -> MatchRules {
        MatchRulesPreferences.makeRules(
            bestOfSets: bestOfSets,
            gamePointStyle: gamePointStyle,
            setTieBreak: setTieBreak,
            finalSetTieBreak: finalSetTieBreak
        )
    }

    static func loadValues(from rules: MatchRules) -> (
        bestOfSets: Int,
        gamePointStyle: GamePointStyle,
        setTieBreak: TieBreakStyle,
        finalSetTieBreak: TieBreakStyle
    ) {
        MatchRulesPreferences.formValues(from: rules)
    }
}
