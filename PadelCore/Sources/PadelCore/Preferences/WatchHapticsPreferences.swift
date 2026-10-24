import Foundation

public enum WatchHapticsPreferences {
    private static let storageKey = "watchHapticsEnabled"

    public static func load() -> Bool {
        UserDefaults.standard.bool(forKey: storageKey)
    }

    public static func save(_ isEnabled: Bool) {
        UserDefaults.standard.set(isEnabled, forKey: storageKey)
    }
}
