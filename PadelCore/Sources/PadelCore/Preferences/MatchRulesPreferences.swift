import Foundation

public enum MatchRulesPreferences {
    private static let storageKey = "lastMatchRules"

    public static func load() -> MatchRules {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let rules = try? JSONDecoder().decode(MatchRules.self, from: data)
        else {
            return .default
        }
        return rules
    }

    public static func save(_ rules: MatchRules) {
        guard let data = try? JSONEncoder().encode(rules) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    public static func summary(for rules: MatchRules) -> String {
        let setsLabel: String = {
            switch bestOfSets(from: rules) {
            case 1: String(localized: "Best of 1")
            case 3: String(localized: "Best of 3")
            default: String(localized: "Best of 5")
            }
        }()

        let deuceLabel: String = {
            switch rules.gamePointStyle {
            case .goldenPoint: String(localized: "Golden point")
            case .advantage: String(localized: "Advantage")
            case .starPoint: String(localized: "Star point")
            }
        }()

        return "\(setsLabel) · \(deuceLabel)"
    }

    public static func bestOfSets(from rules: MatchRules) -> Int {
        switch rules.setsToWin {
        case 1: 1
        case 2: 3
        default: 5
        }
    }

    public static func makeRules(
        bestOfSets: Int,
        gamePointStyle: GamePointStyle,
        setTieBreak: TieBreakStyle = .classic,
        finalSetTieBreak: TieBreakStyle = .superTieBreak10
    ) -> MatchRules {
        let setsToWin: Int = switch bestOfSets {
        case 1: 1
        case 3: 2
        default: 3
        }

        return MatchRules(
            setsToWin: setsToWin,
            gamePointStyle: gamePointStyle,
            setTieBreak: setTieBreak,
            finalSetTieBreak: finalSetTieBreak
        )
    }

    public static func formValues(from rules: MatchRules) -> (
        bestOfSets: Int,
        gamePointStyle: GamePointStyle,
        setTieBreak: TieBreakStyle,
        finalSetTieBreak: TieBreakStyle
    ) {
        (
            bestOfSets(from: rules),
            rules.gamePointStyle,
            rules.setTieBreak,
            rules.finalSetTieBreak
        )
    }
}
