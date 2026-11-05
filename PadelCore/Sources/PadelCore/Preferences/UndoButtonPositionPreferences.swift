import Foundation

public enum UndoButtonPositionPreferences {
    private static let storageKey = "undoButtonPosition"

    public static func load() -> UndoButtonPosition {
        guard
            let raw = UserDefaults.standard.string(forKey: storageKey),
            let position = UndoButtonPosition(rawValue: raw)
        else {
            return .default
        }
        return position
    }

    public static func save(_ position: UndoButtonPosition) {
        UserDefaults.standard.set(position.rawValue, forKey: storageKey)
    }
}
