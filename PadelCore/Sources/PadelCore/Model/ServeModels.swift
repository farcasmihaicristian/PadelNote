/// The service box a serve is delivered from / received in.
public enum ServeSide: String, Codable, Hashable, Sendable {
    /// Deuce court (right). Every game starts here.
    case right
    /// Advantage court (left).
    case left

    public var toggled: ServeSide {
        switch self {
        case .right: .left
        case .left: .right
        }
    }
}

/// The serving rotation chosen for a set. Padel rotates the serve through all
/// four players: the serving team's chosen player, then the receiving team's
/// chosen player, then their respective partners, repeating every four games.
public struct ServeOrder: Codable, Hashable, Sendable {
    /// Player who serves the first game of the set.
    public var firstServer: PlayerSlot
    /// Player who serves the second game (the receiving team's first server).
    public var firstReceiverServer: PlayerSlot

    public init(firstServer: PlayerSlot, firstReceiverServer: PlayerSlot) {
        self.firstServer = firstServer
        self.firstReceiverServer = firstReceiverServer
    }

    /// Standard order derived from a single first-server choice: the opposing
    /// team's player 1 (right) serves second by default.
    public static func standard(firstServer: PlayerSlot) -> ServeOrder {
        let receiverServer: PlayerSlot = firstServer.team == .a ? .sideBPlayer1 : .sideAPlayer1
        return ServeOrder(firstServer: firstServer, firstReceiverServer: receiverServer)
    }

    public static let `default` = ServeOrder.standard(firstServer: .sideAPlayer1)

    /// The four-game rotation order for the set.
    public var rotation: [PlayerSlot] {
        [firstServer, firstReceiverServer, firstServer.partner, firstReceiverServer.partner]
    }

    /// The slot serving game `gameIndexInSet` (0-based) under normal rotation.
    public func server(forGameInSet gameIndexInSet: Int) -> PlayerSlot {
        let order = rotation
        return order[((gameIndexInSet % order.count) + order.count) % order.count]
    }

    /// FIP handoff into the next set: keep the four-player cycle, starting with
    /// whoever is due after `gamesPlayed` games of the previous set (including
    /// the tie-break game when the set finished 7–6). That pair may still change
    /// which partner opens at the set boundary; this is the automatic default.
    public func orderStartingNextSet(afterGamesPlayed gamesPlayed: Int) -> ServeOrder {
        let nextFirst = server(forGameInSet: gamesPlayed)
        let rot = rotation
        guard let idx = rot.firstIndex(of: nextFirst) else {
            return .standard(firstServer: nextFirst)
        }
        let rotated = Array(rot[idx...]) + Array(rot[..<idx])
        return ServeOrder(firstServer: rotated[0], firstReceiverServer: rotated[1])
    }

    /// Aligns a per-set serve-order list to the sets played so far. New sets use
    /// FIP continuation from the previous set’s game count (not a full restart).
    /// The first set derives from `firstServer`. Orders beyond the active set are
    /// trimmed (undo). Shared by the watch coordinator so the rule lives in one
    /// tested place.
    public static func aligned(
        _ orders: [ServeOrder],
        completedSets: [SetScore],
        firstServer: PlayerSlot
    ) -> [ServeOrder] {
        let targetCount = completedSets.count + 1
        var result = orders
        if result.count > targetCount {
            result = Array(result.prefix(targetCount))
        }
        while result.count < targetCount {
            if let previous = result.last, result.count <= completedSets.count {
                let finished = completedSets[result.count - 1]
                let gamesPlayed = finished.gamesA + finished.gamesB
                result.append(previous.orderStartingNextSet(afterGamesPlayed: gamesPlayed))
            } else {
                result.append(result.last ?? ServeOrder.standard(firstServer: firstServer))
            }
        }
        return result
    }
}

/// The serving situation for a single point.
public struct ServeContext: Sendable, Hashable {
    public let servingTeam: Team
    public let servingSlot: PlayerSlot
    public let side: ServeSide
    public let isTieBreak: Bool
    /// True when this point is a golden/star sudden-death deciding point, where
    /// the receiving team chooses the serve side.
    public let isDecidingPoint: Bool

    public init(
        servingTeam: Team,
        servingSlot: PlayerSlot,
        side: ServeSide,
        isTieBreak: Bool,
        isDecidingPoint: Bool
    ) {
        self.servingTeam = servingTeam
        self.servingSlot = servingSlot
        self.side = side
        self.isTieBreak = isTieBreak
        self.isDecidingPoint = isDecidingPoint
    }
}
