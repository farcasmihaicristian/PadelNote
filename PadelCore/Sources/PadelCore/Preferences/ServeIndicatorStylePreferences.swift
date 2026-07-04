import Foundation

public enum ServeIndicatorStylePreferences {
    private static let storageKey = "serveIndicatorStyle"

    public static func load() -> ServeIndicatorStyle {
        guard
            let raw = UserDefaults.standard.string(forKey: storageKey),
            let style = ServeIndicatorStyle(rawValue: raw)
        else {
            return .default
        }
        return style
    }

    public static func save(_ style: ServeIndicatorStyle) {
        UserDefaults.standard.set(style.rawValue, forKey: storageKey)
    }
}
