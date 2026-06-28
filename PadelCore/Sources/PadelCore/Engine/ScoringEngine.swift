import Foundation

public enum ScoringEngine {
    /// Replays a point log from an empty match state.
    public static func replay(events: [PointEvent], rules: MatchRules) -> MatchState {
        events.reduce(into: MatchState(rules: rules)) { state, event in
            state = apply(point: event.team, to: state)
        }
    }

    /// Applies one point to the current match state.
    public static func apply(point winner: Team, to state: MatchState) -> MatchState {
        guard !state.isMatchOver else { return state }

        var next = state
        if next.isTieBreak {
            applyTieBreakPoint(winner: winner, to: &next)
        } else {
            applyRegularPoint(winner: winner, to: &next)
        }
        return next
    }

    // MARK: - Regular game

    private static func applyRegularPoint(winner: Team, to state: inout MatchState) {
        if state.pointA == 3 && state.pointB == 3 && state.advantageTeam == nil {
            handleDeuce(winner: winner, to: &state)
            return
        }

        if let advantageTeam = state.advantageTeam {
            if winner == advantageTeam {
                awardGame(to: winner, state: &state)
            } else {
                state.advantageTeam = nil
                state.pointA = 3
                state.pointB = 3
                state.deuceCount += 1
            }
            return
        }

        incrementRegularPoint(winner: winner, to: &state)
    }

    private static func handleDeuce(winner: Team, to state: inout MatchState) {
        if state.deuceCount == 0 {
            state.deuceCount = 1
        }

        switch state.rules.gamePointStyle {
        case .goldenPoint:
            awardGame(to: winner, state: &state)
        case .advantage:
            state.advantageTeam = winner
        case .starPoint:
            if state.deuceCount >= 3 {
                awardGame(to: winner, state: &state)
            } else {
                state.advantageTeam = winner
            }
        }
    }

    private static func incrementRegularPoint(winner: Team, to state: inout MatchState) {
        switch winner {
        case .a:
            if state.pointA == 3 && state.pointB < 3 {
                awardGame(to: .a, state: &state)
            } else if state.pointA < 3 {
                state.pointA += 1
                if state.pointA == 3 && state.pointB == 3 {
                    state.deuceCount = max(state.deuceCount, 1)
                }
            }
        case .b:
            if state.pointB == 3 && state.pointA < 3 {
                awardGame(to: .b, state: &state)
            } else if state.pointB < 3 {
                state.pointB += 1
                if state.pointA == 3 && state.pointB == 3 {
                    state.deuceCount = max(state.deuceCount, 1)
                }
            }
        }
    }

    // MARK: - Tie-break

    private static func applyTieBreakPoint(winner: Team, to state: inout MatchState) {
        switch winner {
        case .a: state.tieBreakPointsA += 1
        case .b: state.tieBreakPointsB += 1
        }

        let style = activeTieBreakStyle(for: state)
        let target = style.pointsToWin
        let a = state.tieBreakPointsA
        let b = state.tieBreakPointsB

        guard max(a, b) >= target, abs(a - b) >= 2 else { return }

        let setWinner: Team = a > b ? .a : .b
        let gamesA = state.rules.gamesPerSet + (setWinner == .a ? 1 : 0)
        let gamesB = state.rules.gamesPerSet + (setWinner == .b ? 1 : 0)
        completeSet(
            state: &state,
            gamesA: gamesA,
            gamesB: gamesB,
            tieBreakA: a,
            tieBreakB: b
        )
    }

    // MARK: - Game / set / match completion

    private static func awardGame(to winner: Team, state: inout MatchState) {
        resetGamePoints(state: &state)

        switch winner {
        case .a: state.gamesA += 1
        case .b: state.gamesB += 1
        }

        evaluateSetProgress(state: &state)
    }

    private static func evaluateSetProgress(state: inout MatchState) {
        let gamesA = state.gamesA
        let gamesB = state.gamesB
        let perSet = state.rules.gamesPerSet

        if gamesA == perSet && gamesB == perSet {
            let style = activeTieBreakStyle(for: state)
            if style != .none {
                state.isTieBreak = true
                return
            }
        }

        if setWon(gamesA: gamesA, gamesB: gamesB, rules: state.rules) {
            completeSet(state: &state, gamesA: gamesA, gamesB: gamesB)
        }
    }

    private static func setWon(gamesA: Int, gamesB: Int, rules: MatchRules) -> Bool {
        let leader = max(gamesA, gamesB)
        let trailer = min(gamesA, gamesB)

        guard leader >= rules.gamesPerSet else { return false }

        if rules.winByTwoGames {
            return leader - trailer >= 2
        }
        return leader > rules.gamesPerSet
    }

    private static func completeSet(
        state: inout MatchState,
        gamesA: Int,
        gamesB: Int,
        tieBreakA: Int? = nil,
        tieBreakB: Int? = nil
    ) {
        state.completedSets.append(
            SetScore(gamesA: gamesA, gamesB: gamesB, tieBreakA: tieBreakA, tieBreakB: tieBreakB)
        )
        state.gamesA = 0
        state.gamesB = 0
        state.isTieBreak = false
        state.tieBreakPointsA = 0
        state.tieBreakPointsB = 0
        resetGamePoints(state: &state)

        let setsA = state.setsWonA
        let setsB = state.setsWonB
        if setsA >= state.rules.setsToWin {
            state.isMatchOver = true
            state.winner = .a
        } else if setsB >= state.rules.setsToWin {
            state.isMatchOver = true
            state.winner = .b
        }
    }

    private static func resetGamePoints(state: inout MatchState) {
        state.pointA = 0
        state.pointB = 0
        state.advantageTeam = nil
        state.deuceCount = 0
    }

    private static func activeTieBreakStyle(for state: MatchState) -> TieBreakStyle {
        state.isDecidingSet ? state.rules.finalSetTieBreak : state.rules.setTieBreak
    }
}

/// Mutable scoring session with undo via event replay.
///
/// The running `MatchState` after each event is cached in `stateHistory` so that
/// reading `state`, adding a point, or undoing is O(1) instead of replaying the
/// full event log every time. `stateHistory[i]` is the state after `i` events,
/// with index `0` holding the initial empty state.
public struct ScoringSession: Sendable {
    public private(set) var rules: MatchRules
    public private(set) var events: [PointEvent]
    private var stateHistory: [MatchState]

    public init(rules: MatchRules) {
        self.rules = rules
        self.events = []
        self.stateHistory = [MatchState(rules: rules)]
    }

    public init(rules: MatchRules, events: [PointEvent]) {
        self.rules = rules
        self.events = events

        var history = [MatchState(rules: rules)]
        history.reserveCapacity(events.count + 1)
        var current = history[0]
        for event in events {
            current = ScoringEngine.apply(point: event.team, to: current)
            history.append(current)
        }
        self.stateHistory = history
    }

    public var state: MatchState {
        // `stateHistory` always holds the initial state at index 0 and grows/
        // shrinks in lockstep with `events`, so `last` is never nil. The assert
        // catches a future change that breaks that invariant in debug; the
        // fallback keeps release builds safe.
        assert(!stateHistory.isEmpty, "stateHistory must always contain the initial state")
        return stateHistory.last ?? MatchState(rules: rules)
    }

    public mutating func addPoint(for team: Team) {
        let current = state
        guard !current.isMatchOver else { return }
        events.append(PointEvent(team: team))
        stateHistory.append(ScoringEngine.apply(point: team, to: current))
    }

    @discardableResult
    public mutating func undo() -> Bool {
        guard !events.isEmpty else { return false }
        events.removeLast()
        stateHistory.removeLast()
        return true
    }
}
