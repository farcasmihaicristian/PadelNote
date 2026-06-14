import Foundation
import SwiftData

@Model
public final class AppUser {
    @Attribute(.unique) public var appleUserID: String
    public var displayName: String
    public var email: String?
    public var playerID: UUID
    public var createdAt: Date
    public var lastSignedInAt: Date

    public init(
        appleUserID: String,
        displayName: String,
        email: String? = nil,
        playerID: UUID,
        createdAt: Date = .now,
        lastSignedInAt: Date = .now
    ) {
        self.appleUserID = appleUserID
        self.displayName = displayName
        self.email = email
        self.playerID = playerID
        self.createdAt = createdAt
        self.lastSignedInAt = lastSignedInAt
    }
}
