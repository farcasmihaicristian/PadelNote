import Foundation

/// The serve under which a single point was played.
public struct PointServe: Sendable, Hashable {
    public let servingSlot: PlayerSlot
    public let servingTeam: Team
    public let side: ServeSide
    public let isTieBreak: Bool
    public let winner: Team
    public let setIndex: Int

    public init(
        servingSlot: PlayerSlot,
        servingTeam: Team,
        side: ServeSide,
        isTieBreak: Bool,
        winner: Team,
        setIndex: Int
    ) {
        self.servingSlot = servingSlot
        self.servingTeam = servingTeam
        self.side = side
        self.isTieBreak = isTieBreak
        self.winner = winner
        self.setIndex = setIndex
    }
}

/// A completed service game and whether the server's team held it.
public struct ServiceGame: Sendable, Hashable {
    public let serverSlot: PlayerSlot
    public let serverTeam: Team
    public let winner: Team
    public let isTieBreak: Bool
    public let setIndex: Int

    public var held: Bool { winner == serverTeam }

    public init(
        serverSlot: PlayerSlot,
        serverTeam: Team,
        winner: Team,
        isTieBreak: Bool,
        setIndex: Int
    ) {
        self.serverSlot = serverSlot
        self.serverTeam = serverTeam
        self.winner = winner
        self.isTieBreak = isTieBreak
        self.setIndex = setIndex
    }
}

/// Serve information derived from a point log.
public struct ServeTimeline: Sendable {
    /// One entry per played point, in order.
    public let points: [PointServe]
    /// Completed service games (tie-breaks flagged via `isTieBreak`).
    public let games: [ServiceGame]
    /// The serve for the next point to be played (default sides; no override).
    public let upcoming: ServeContext
}

/// Derives padel serve rotation (which player serves, from which side) from a
/// point log plus the per-set serving order, without storing per-point data.
public enum ServeEngine {
    public static func timeline(
        events: [PointEvent],
        rules: MatchRules,
        orders: [ServeOrder]
    ) -> ServeTimeline {
        var points: [PointServe] = []
        var games: [ServiceGame] = []

        var prevState = MatchState(rules: rules)
        var setIndex = 0
        var gameIndexInSet = 0
        var pointsInGame = 0
        var tieBreakPointIndex = 0

        for event in events {
            let order = order(for: setIndex, orders: orders)
            let context = makeContext(
                state: prevState,
                rules: rules,
                order: order,
                gameIndexInSet: gameIndexInSet,
                pointsInGame: pointsInGame,
                tieBreakPointIndex: tieBreakPointIndex,
                decidingSideOverride: nil
            )

            points.append(
                PointServe(
                    servingSlot: context.servingSlot,
                    servingTeam: context.servingTeam,
                    side: context.side,
                    isTieBreak: context.isTieBreak,
                    winner: event.team,
                    setIndex: setIndex
                )
            )

            let newState = ScoringEngine.apply(point: event.team, to: prevState)

            let setCompleted = newState.completedSets.count > prevState.completedSets.count
            if setCompleted {
                let gameWinner = newState.completedSets.last?.winner ?? event.team
                games.append(
                    ServiceGame(
                        serverSlot: context.servingSlot,
                        serverTeam: context.servingTeam,
                        winner: gameWinner,
                        isTieBreak: prevState.isTieBreak,
                        setIndex: setIndex
                    )
                )
                setIndex = newState.completedSets.count
                gameIndexInSet = 0
                pointsInGame = 0
                tieBreakPointIndex = 0
            } else if newState.isTieBreak {
                if prevState.isTieBreak {
                    tieBreakPointIndex += 1
                } else {
                    // The point just completed the games-per-set game and started
                    // the tie-break.
                    let gameWinner: Team = newState.gamesA > prevState.gamesA ? .a : .b
                    games.append(
                        ServiceGame(
                            serverSlot: context.servingSlot,
                            serverTeam: context.servingTeam,
                            winner: gameWinner,
                            isTieBreak: false,
                            setIndex: setIndex
                        )
                    )
                    gameIndexInSet = newState.gamesA + newState.gamesB
                    pointsInGame = 0
                    tieBreakPointIndex = 0
                }
            } else {
                let gamesNow = newState.gamesA + newState.gamesB
                let gamesPrev = prevState.gamesA + prevState.gamesB
                if gamesNow > gamesPrev {
                    let gameWinner: Team = newState.gamesA > prevState.gamesA ? .a : .b
                    games.append(
                        ServiceGame(
                            serverSlot: context.servingSlot,
                            serverTeam: context.servingTeam,
                            winner: gameWinner,
                            isTieBreak: false,
                            setIndex: setIndex
                        )
                    )
                    gameIndexInSet = gamesNow
                    pointsInGame = 0
                } else {
                    pointsInGame += 1
                }
            }

            prevState = newState
        }

        let upcoming = makeContext(
            state: prevState,
            rules: rules,
            order: order(for: setIndex, orders: orders),
            gameIndexInSet: gameIndexInSet,
            pointsInGame: pointsInGame,
            tieBreakPointIndex: tieBreakPointIndex,
            decidingSideOverride: nil
        )

        return ServeTimeline(points: points, games: games, upcoming: upcoming)
    }

    /// The serve for the next point. Applies `decidingSideOverride` when the next
    /// point is a golden/star deciding point (receiver chooses the side).
    public static func currentServe(
        events: [PointEvent],
        rules: MatchRules,
        orders: [ServeOrder],
        decidingSideOverride: ServeSide? = nil
    ) -> ServeContext {
        let upcoming = timeline(events: events, rules: rules, orders: orders).upcoming
        guard upcoming.isDecidingPoint, let override = decidingSideOverride else {
            return upcoming
        }
        return ServeContext(
            servingTeam: upcoming.servingTeam,
            servingSlot: upcoming.servingSlot,
            side: override,
            isTieBreak: upcoming.isTieBreak,
            isDecidingPoint: upcoming.isDecidingPoint
        )
    }

    // MARK: - Helpers

    private static func order(for setIndex: Int, orders: [ServeOrder]) -> ServeOrder {
        if orders.isEmpty { return .default }
        if setIndex < orders.count { return orders[setIndex] }
        return orders[orders.count - 1]
    }

    private static func makeContext(
        state: MatchState,
        rules: MatchRules,
        order: ServeOrder,
        gameIndexInSet: Int,
        pointsInGame: Int,
        tieBreakPointIndex: Int,
        decidingSideOverride: ServeSide?
    ) -> ServeContext {
        if state.isTieBreak {
            let block = tieBreakPointIndex == 0 ? 0 : ((tieBreakPointIndex - 1) / 2) + 1
            let slot = order.server(forGameInSet: gameIndexInSet + block)
            let side: ServeSide = tieBreakPointIndex % 2 == 0 ? .right : .left
            return ServeContext(
                servingTeam: slot.team,
                servingSlot: slot,
                side: side,
                isTieBreak: true,
                isDecidingPoint: false
            )
        }

        let slot = order.server(forGameInSet: gameIndexInSet)
        let deciding = isDecidingPoint(state: state, rules: rules)
        let baseSide: ServeSide = pointsInGame % 2 == 0 ? .right : .left
        let side = deciding ? (decidingSideOverride ?? baseSide) : baseSide
        return ServeContext(
            servingTeam: slot.team,
            servingSlot: slot,
            side: side,
            isTieBreak: false,
            isDecidingPoint: deciding
        )
    }

    private static func isDecidingPoint(state: MatchState, rules: MatchRules) -> Bool {
        state.isSuddenDeathPoint
    }
}
