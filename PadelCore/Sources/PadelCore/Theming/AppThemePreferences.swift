import Foundation

public enum AppThemePreferences {
    private static let storageKey = "selectedAppThemeID"

    public static func load() -> AppTheme {
        AppThemeCatalog.theme(withID: loadID())
    }

    public static func save(_ theme: AppTheme) {
        saveID(theme.id)
    }

    public static func loadID() -> String? {
        UserDefaults.standard.string(forKey: storageKey)
    }

    public static func saveID(_ id: String?) {
        guard let id else {
            UserDefaults.standard.removeObject(forKey: storageKey)
            return
        }
        UserDefaults.standard.set(id, forKey: storageKey)
    }
}
