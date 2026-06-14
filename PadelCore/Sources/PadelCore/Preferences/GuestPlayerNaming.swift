import Foundation

public enum GuestPlayerNaming {
    /// Picker sentinel — not stored as a player name.
    public static let guestPickerToken = "__guest__"

    private static let counterKey = "guestPlayerNextNumber"

    public static func displayName(number: Int) -> String {
        String(localized: "Guest \(number)")
    }

    public static func isGuestName(_ name: String) -> Bool {
        parseNumber(from: name) != nil
    }

    public static func nextName(avoiding reservedNames: Set<String>) -> String {
        var candidate = max(storedCounter(), highestNumber(in: reservedNames) + 1)
        while reservedNames.contains(displayName(number: candidate)) {
            candidate += 1
        }
        UserDefaults.standard.set(candidate + 1, forKey: counterKey)
        return displayName(number: candidate)
    }

    private static func storedCounter() -> Int {
        max(UserDefaults.standard.integer(forKey: counterKey), 1)
    }

    private static func highestNumber(in names: Set<String>) -> Int {
        names.compactMap(parseNumber(from:)).max() ?? 0
    }

    private static func parseNumber(from name: String) -> Int? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefixes = [String(localized: "Guest"), "Guest"]

        for prefix in prefixes {
            let marker = "\(prefix) "
            guard trimmed.hasPrefix(marker) else { continue }
            let suffix = trimmed.dropFirst(marker.count).trimmingCharacters(in: .whitespacesAndNewlines)
            if let number = Int(suffix), number > 0 {
                return number
            }
        }
        return nil
    }
}
