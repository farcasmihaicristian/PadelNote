import Foundation

public enum MeProfilePreferences {
    private static let preferredSlotKey = "mePreferredPlayerSlot"
    private static let offeredPastMatchLinkKey = "meOfferedPastMatchLink"

    public static func preferredSlot() -> PlayerSlot {
        guard
            let rawValue = UserDefaults.standard.string(forKey: preferredSlotKey),
            let slot = PlayerSlot(rawValue: rawValue)
        else {
            return .sideAPlayer1
        }
        return slot
    }

    public static func savePreferredSlot(_ slot: PlayerSlot) {
        UserDefaults.standard.set(slot.rawValue, forKey: preferredSlotKey)
    }

    public static var hasOfferedPastMatchLink: Bool {
        UserDefaults.standard.bool(forKey: offeredPastMatchLinkKey)
    }

    public static func markPastMatchLinkOffered() {
        UserDefaults.standard.set(true, forKey: offeredPastMatchLinkKey)
    }
}
