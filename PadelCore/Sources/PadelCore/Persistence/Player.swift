import Foundation
import SwiftData

@Model
public final class Player {
    @Attribute(.unique) public var id: UUID
    public var displayName: String
    public var normalizedName: String
    public var createdAt: Date
    public var isOwnedByCurrentUser: Bool

    public init(
        id: UUID = UUID(),
        displayName: String,
        normalizedName: String? = nil,
        createdAt: Date = .now,
        isOwnedByCurrentUser: Bool = false
    ) {
        self.id = id
        self.displayName = displayName
        self.normalizedName = normalizedName ?? PlayerPersistence.normalizeName(displayName)
        self.createdAt = createdAt
        self.isOwnedByCurrentUser = isOwnedByCurrentUser
    }
}
