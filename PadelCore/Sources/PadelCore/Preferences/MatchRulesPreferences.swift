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
            switch rules.setsToWin {
            case 1: String(localized: "Best of 1")
            case 2: String(localized: "Best of 3")
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
}
