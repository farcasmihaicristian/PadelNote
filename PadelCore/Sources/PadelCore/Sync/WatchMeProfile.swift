import Foundation

/// ME profile synced from iPhone to Apple Watch for match setup defaults.
public struct WatchMeProfile: Codable, Sendable, Hashable {
    public var displayName: String
    public var preferredSlot: PlayerSlot

    public init(displayName: String, preferredSlot: PlayerSlot = .sideAPlayer1) {
        self.displayName = displayName
        self.preferredSlot = preferredSlot
    }
}
