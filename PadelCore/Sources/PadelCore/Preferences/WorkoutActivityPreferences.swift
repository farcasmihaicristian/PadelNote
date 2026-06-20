import Foundation

public enum WorkoutActivityPreferences {
    private static let storageKey = "workoutActivityKind"

    public static func load() -> WorkoutActivityKind {
        guard
            let raw = UserDefaults.standard.string(forKey: storageKey),
            let kind = WorkoutActivityKind(rawValue: raw)
        else {
            return .default
        }
        return kind
    }

    public static func save(_ kind: WorkoutActivityKind) {
        UserDefaults.standard.set(kind.rawValue, forKey: storageKey)
    }
}
