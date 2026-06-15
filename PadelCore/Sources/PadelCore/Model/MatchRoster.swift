import Foundation

public enum PlayerCourtSide: Int, Sendable, Hashable, Codable {
    case left = 0
    case right = 1

    public var label: String {
        switch self {
        case .left:
            String(localized: "Left side")
        case .right:
            String(localized: "Right side")
        }
    }
}

public struct MatchPlayerRosterEntry: Sendable, Hashable, Codable {
    public let id: UUID?
    public let name: String?

    public init(id: UUID? = nil, name: String? = nil) {
        self.id = id
        self.name = name?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

public struct MatchRoster: Sendable, Hashable, Codable {
    public let sideA: [MatchPlayerRosterEntry]
    public let sideB: [MatchPlayerRosterEntry]

    public static let empty = MatchRoster()

    public init(
        sideA: [MatchPlayerRosterEntry] = [.init(), .init()],
        sideB: [MatchPlayerRosterEntry] = [.init(), .init()]
    ) {
        self.sideA = sideA
        self.sideB = sideB
    }

    public init(
        playerA1ID: UUID?, playerA1Name: String?,
        playerA2ID: UUID?, playerA2Name: String?,
        playerB1ID: UUID?, playerB1Name: String?,
        playerB2ID: UUID?, playerB2Name: String?
    ) {
        self.sideA = [
            MatchPlayerRosterEntry(id: playerA1ID, name: playerA1Name),
            MatchPlayerRosterEntry(id: playerA2ID, name: playerA2Name),
        ]
        self.sideB = [
            MatchPlayerRosterEntry(id: playerB1ID, name: playerB1Name),
            MatchPlayerRosterEntry(id: playerB2ID, name: playerB2Name),
        ]
    }

    public var allEntries: [MatchPlayerRosterEntry] {
        sideA + sideB
    }

    public var linkedPlayerIDs: [UUID] {
        allEntries.compactMap(\.id)
    }

    public func team(for playerID: UUID) -> Team? {
        if sideA.contains(where: { $0.id == playerID }) { return .a }
        if sideB.contains(where: { $0.id == playerID }) { return .b }
        return nil
    }

    public func contains(playerID: UUID) -> Bool {
        team(for: playerID) != nil
    }

    public func partnerIDs(for playerID: UUID) -> [UUID] {
        guard let team = team(for: playerID) else { return [] }
        let side = team == .a ? sideA : sideB
        return side.compactMap(\.id).filter { $0 != playerID }
    }

    public func courtSide(for playerID: UUID) -> PlayerCourtSide? {
        guard let team = team(for: playerID) else { return nil }
        let side = team == .a ? sideA : sideB
        guard let index = side.firstIndex(where: { $0.id == playerID }) else { return nil }
        return index == 0 ? .right : .left
    }

    public func placementDescription(for playerID: UUID) -> String? {
        courtSide(for: playerID)?.label
    }
}

public struct MatchPlayerSlotSelection: Sendable, Hashable {
    public var name: String
    public var playerID: UUID?

    public init(name: String = "", playerID: UUID? = nil) {
        self.name = name
        self.playerID = playerID
    }

    public var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var hasContent: Bool {
        !trimmedName.isEmpty || playerID != nil
    }
}

public struct MatchPlayerSetup: Sendable, Hashable {
    public var sideAPlayer1: MatchPlayerSlotSelection
    public var sideAPlayer2: MatchPlayerSlotSelection
    public var sideBPlayer1: MatchPlayerSlotSelection
    public var sideBPlayer2: MatchPlayerSlotSelection

    public static let empty = MatchPlayerSetup()

    public init(
        sideAPlayer1: MatchPlayerSlotSelection = .init(),
        sideAPlayer2: MatchPlayerSlotSelection = .init(),
        sideBPlayer1: MatchPlayerSlotSelection = .init(),
        sideBPlayer2: MatchPlayerSlotSelection = .init()
    ) {
        self.sideAPlayer1 = sideAPlayer1
        self.sideAPlayer2 = sideAPlayer2
        self.sideBPlayer1 = sideBPlayer1
        self.sideBPlayer2 = sideBPlayer2
    }

    public var playerNames: MatchPlayerNames {
        MatchPlayerNames(
            playerA1: sideAPlayer1.name,
            playerA2: sideAPlayer2.name,
            playerB1: sideBPlayer1.name,
            playerB2: sideBPlayer2.name
        )
    }
}
