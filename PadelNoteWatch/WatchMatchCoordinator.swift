import Foundation
import Observation
import PadelCore

@Observable
@MainActor
final class WatchMatchCoordinator {
    enum Phase: Equatable {
        case idle
        case live
        case summary
    }

    enum WorkoutWarning: Equatable {
        case unavailable
        case stoppedMidMatch(String)
        case notSavedTooShort
        case failed(String)

        var message: String {
            switch self {
            case .unavailable:
                String(localized: "Workout recording unavailable. Scoring will still work.")
            case .stoppedMidMatch(let message), .failed(let message):
                message
            case .notSavedTooShort:
                String(localized: "Workout not saved to Apple Health — match was under 10 minutes.")
            }
        }

        var isInformational: Bool {
            self == .notSavedTooShort
        }
    }

    var phase: Phase = .idle
    var session: ScoringSession?
    var matchID: UUID?
    var startedAt = Date.now
    var rules: MatchRules = .default
    var bestOfSets = 3
    var gamePointStyle = MatchRules.default.gamePointStyle
    var setTieBreak = MatchRules.default.setTieBreak
    var finalSetTieBreak = MatchRules.default.finalSetTieBreak
    var playerSetup = MatchPlayerSetup.empty
    /// Court lineup per set (index = set number), capturing left/right side
    /// changes made between sets. Sent with the completed match for per-set insights.
    var setLineups: [MatchPlayerNames] = []
    /// Player who serves the first game of the match.
    var firstServer: PlayerSlot = .sideAPlayer1
    /// Serving order per set (index = set number). Sent with the completed match
    /// for per-set serve insights.
    var setServeOrders: [ServeOrder] = []
    /// Receiver's chosen serve side for the upcoming golden/star deciding point.
    /// Cleared once that point is played or undone.
    var decidingSideOverride: ServeSide?
    var knownPlayerNames: [String] = []
    var meProfile: WatchMeProfile?
    var healthAuthDenied = false
    var workoutWarning: WorkoutWarning?
    var isSaving = false
    var pendingSyncCount = 0
    private var endedEarly = false
    private var matchActivityEndedAt: Date?
    private var workoutStartTask: Task<Void, Never>?
    private var hasPrepared = false

    /// Tracks the "Continue new set" flow: after a decided match is continued,
    /// the original decided result is restored if the user ends without playing
    /// any further point. One explicit state replaces the prior pair of optionals.
    private enum ContinuationState: Equatable {
        case none
        /// `rules`/`eventCount` captured at the moment the decided match was continued.
        case pending(rules: MatchRules, eventCount: Int)
    }
    private var continuation: ContinuationState = .none

    let workoutRecorder: any WorkoutRecording
    let syncService: any MatchSyncPublishing
    var onThemeChanged: ((AppTheme) -> Void)?
    var onServeIndicatorStyleChanged: ((ServeIndicatorStyle) -> Void)?

    init(workoutRecorder: any WorkoutRecording, syncService: any MatchSyncPublishing) {
        self.workoutRecorder = workoutRecorder
        self.syncService = syncService
        configurePhoneContextSync()
        configureWorkoutErrorHandling()
    }

    private func configureWorkoutErrorHandling() {
        workoutRecorder.onRecordingError = { [weak self] message in
            self?.workoutWarning = .stoppedMidMatch(message)
        }
    }

    private func configurePhoneContextSync() {
        guard let publisher = syncService as? WatchConnectivityPublisher else { return }
        publisher.onPhoneContextUpdate = { [weak self] payload in
            self?.applyPhoneContext(payload)
        }
    }

    private func applyPhoneContext(_ payload: PhoneWatchSyncPayload) {
        MatchRulesPreferences.save(payload.rules)
        WorkoutActivityPreferences.save(payload.workoutActivity ?? .default)
        if let themeID = payload.themeID {
            AppThemePreferences.saveID(themeID)
            onThemeChanged?(AppThemeCatalog.theme(withID: themeID))
        }
        if let serveIndicatorStyle = payload.serveIndicatorStyle {
            ServeIndicatorStylePreferences.save(serveIndicatorStyle)
            onServeIndicatorStyleChanged?(serveIndicatorStyle)
        }
        knownPlayerNames = payload.knownPlayerNames
        meProfile = payload.meProfile
        guard phase == .idle else { return }

        let values = MatchRulesPreferences.formValues(from: payload.rules)
        bestOfSets = values.bestOfSets
        gamePointStyle = values.gamePointStyle
        setTieBreak = values.setTieBreak
        finalSetTieBreak = values.finalSetTieBreak
        rules = payload.rules
        applyMeProfileDefaultIfNeeded()
    }

    var sortedKnownPlayerNames: [String] {
        knownPlayerNames.sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
    }

    var currentState: MatchState? {
        session?.state
    }

    var activePlayerNames: MatchPlayerNames {
        playerSetup.playerNames
    }

    func displaySideLabel(for team: Team) -> String {
        activePlayerNames.courtSideLabel(for: team)
    }

    private struct ServeCacheKey: Equatable {
        let eventCount: Int
        let decidingSideOverride: ServeSide?
        let serveOrders: [ServeOrder]
    }

    /// Memoizes the last `currentServe` result so the several reads per SwiftUI
    /// render (and `publishSnapshot`) don't each replay the event log. Ignored by
    /// observation so writing it during a body read doesn't invalidate the view.
    @ObservationIgnored private var serveCache: (key: ServeCacheKey, value: ServeContext?)?

    /// The serve for the next point (which player serves, from which side),
    /// honoring any receiver side choice for a deciding point.
    var currentServe: ServeContext? {
        guard phase == .live, let session, !session.state.isMatchOver else { return nil }

        let key = ServeCacheKey(
            eventCount: session.events.count,
            decidingSideOverride: decidingSideOverride,
            serveOrders: setServeOrders
        )
        if let serveCache, serveCache.key == key {
            return serveCache.value
        }

        let value = ServeEngine.currentServe(
            events: session.events,
            rules: rules,
            orders: setServeOrders,
            decidingSideOverride: decidingSideOverride
        )
        serveCache = (key, value)
        return value
    }

    /// True when the next point is a golden/star deciding point that still needs
    /// the receiving team to choose the serve side.
    var needsDecidingSideChoice: Bool {
        guard let serve = currentServe else { return false }
        return serve.isDecidingPoint && decidingSideOverride == nil
    }

    /// Picks the receiver's serve side for the upcoming deciding point.
    func chooseDecidingSide(_ side: ServeSide) {
        decidingSideOverride = side
        publishSnapshot()
    }

    /// Re-points the serve indicator by changing who serves first this set.
    /// Allowed only at a set boundary (0-0), the same gate as side swaps.
    func setFirstServerForCurrentSet(_ slot: PlayerSlot) {
        guard canSwapSides, let session else { return }
        firstServer = slot
        let activeSetIndex = session.state.completedSets.count
        let order = ServeOrder.standard(firstServer: slot)
        if activeSetIndex < setServeOrders.count {
            setServeOrders[activeSetIndex] = order
        } else {
            syncSetServeOrders()
            if activeSetIndex < setServeOrders.count {
                setServeOrders[activeSetIndex] = order
            }
        }
        persistLiveState()
        publishSnapshot()
    }

    /// Sides can only be switched at the start of a set (fully at 0-0): before
    /// the first point of the match, or between sets after one completes.
    var canSwapSides: Bool {
        guard phase == .live, let state = currentState, !state.isMatchOver else { return false }
        return state.gamesA == 0 && state.gamesB == 0
            && state.pointA == 0 && state.pointB == 0
            && !state.isTieBreak
            && state.tieBreakPointsA == 0 && state.tieBreakPointsB == 0
            && state.advantageTeam == nil
    }

    func toggleLeftRightSides(for team: Team) {
        guard canSwapSides else { return }

        var setup = playerSetup
        switch team {
        case .a:
            swap(&setup.sideAPlayer1, &setup.sideAPlayer2)
        case .b:
            swap(&setup.sideBPlayer1, &setup.sideBPlayer2)
        }
        playerSetup = setup
        syncSetLineups()
        persistLiveState()
        publishSnapshot()
    }

    /// Keeps `setLineups` aligned with the sets played so far: one entry per
    /// started set (including the active one). New sets inherit the current
    /// orientation; undoing back into an earlier set trims later entries and
    /// restores that set's lineup.
    private func syncSetLineups() {
        guard let session else {
            setLineups = []
            return
        }

        let activeSetIndex = session.state.completedSets.count
        let targetCount = activeSetIndex + 1

        if setLineups.count > targetCount {
            setLineups = Array(setLineups.prefix(targetCount))
            playerSetup = makeSetup(from: setLineups[activeSetIndex])
        }

        while setLineups.count < targetCount {
            setLineups.append(activePlayerNames)
        }

        setLineups[activeSetIndex] = activePlayerNames
    }

    /// Keeps `setServeOrders` aligned with the sets played so far. Unlike the
    /// lineup, the serving order is fixed once a set starts: new sets inherit the
    /// previous set's order (or derive from `firstServer` for the first set).
    private func syncSetServeOrders() {
        guard let session else {
            setServeOrders = []
            return
        }

        setServeOrders = ServeOrder.aligned(
            setServeOrders,
            completedSetCount: session.state.completedSets.count,
            firstServer: firstServer
        )
    }

    private func makeSetup(from names: MatchPlayerNames) -> MatchPlayerSetup {
        MatchPlayerSetup(
            sideAPlayer1: .init(name: names.playerA1Name ?? ""),
            sideAPlayer2: .init(name: names.playerA2Name ?? ""),
            sideBPlayer1: .init(name: names.playerB1Name ?? ""),
            sideBPlayer2: .init(name: names.playerB2Name ?? "")
        )
    }

    func prepare() async {
        guard !hasPrepared else { return }
        hasPrepared = true

        syncService.activate()
        await workoutRecorder.requestAuthorization()
        healthAuthDenied = workoutRecorder.authorizationDenied
        loadIdleSetup()
        applyMeProfileDefaultIfNeeded()
        refreshPendingSyncCount()
        restoreInterruptedMatchIfNeeded()
    }

    private func restoreInterruptedMatchIfNeeded() {
        guard phase == .idle, let saved = WatchMatchStore.loadLiveMatch() else { return }

        rules = saved.rules
        let values = MatchRulesPreferences.formValues(from: saved.rules)
        bestOfSets = values.bestOfSets
        gamePointStyle = values.gamePointStyle
        setTieBreak = values.setTieBreak
        finalSetTieBreak = values.finalSetTieBreak

        matchID = saved.matchID
        startedAt = saved.startedAt
        session = ScoringSession(rules: saved.rules, events: saved.events)
        playerSetup = MatchPlayerSetup(
            sideAPlayer1: .init(name: saved.playerNames.playerA1Name ?? ""),
            sideAPlayer2: .init(name: saved.playerNames.playerA2Name ?? ""),
            sideBPlayer1: .init(name: saved.playerNames.playerB1Name ?? ""),
            sideBPlayer2: .init(name: saved.playerNames.playerB2Name ?? "")
        )
        setLineups = saved.setLineups
        setServeOrders = saved.setServeOrders
        firstServer = saved.setServeOrders.first?.firstServer ?? .sideAPlayer1
        decidingSideOverride = nil
        workoutWarning = nil
        endedEarly = false
        matchActivityEndedAt = nil
        phase = .live
        syncSetLineups()
        syncSetServeOrders()
        publishSnapshot()
        startWorkoutInBackground()
    }

    func startMatch() {
        guard phase == .idle else { return }

        rules = buildRules()
        MatchRulesPreferences.save(rules)
        matchID = UUID()
        startedAt = .now
        session = ScoringSession(rules: rules)
        workoutWarning = nil
        endedEarly = false
        continuation = .none
        setLineups = []
        setServeOrders = []
        decidingSideOverride = nil

        phase = .live
        syncSetLineups()
        syncSetServeOrders()
        persistLiveState()
        publishSnapshot()
        startWorkoutInBackground()
    }

    private func startWorkoutInBackground() {
        workoutStartTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await workoutRecorder.start()
            } catch {
                guard !Task.isCancelled else { return }
                workoutWarning = .unavailable
            }
        }
    }

    private func persistLiveState() {
        guard phase == .live, let session, let matchID else { return }
        WatchMatchStore.saveLiveMatch(
            WatchMatchStore.LiveMatch(
                matchID: matchID,
                startedAt: startedAt,
                rules: rules,
                events: session.events,
                playerNames: activePlayerNames,
                setLineups: setLineups,
                setServeOrders: setServeOrders
            )
        )
    }

    func addPoint(for team: Team) {
        guard var session, !session.state.isMatchOver else { return }
        session.addPoint(for: team)
        self.session = session

        // A real point was played after "Continue new set", so the prior
        // completion no longer applies.
        if case let .pending(_, eventCount) = continuation, session.events.count > eventCount {
            continuation = .none
        }

        decidingSideOverride = nil
        syncSetLineups()
        syncSetServeOrders()
        persistLiveState()

        if session.state.isMatchOver {
            transitionToSummary(endedEarly: false)
        } else {
            publishSnapshot()
        }
    }

    func undo() {
        guard var session, phase == .live else { return }
        guard session.undo() else { return }
        self.session = session
        decidingSideOverride = nil
        syncSetLineups()
        syncSetServeOrders()
        persistLiveState()
        publishSnapshot()
    }

    func endMatchEarly() {
        guard let events = session?.events, !events.isEmpty else { return }

        // If the user tapped "Continue new set" but played no further points,
        // restore the original rules so the decided winner is preserved.
        if case let .pending(originalRules, eventCount) = continuation,
           events.count == eventCount {
            rules = originalRules
            session = ScoringSession(rules: originalRules, events: events)
            continuation = .none
            transitionToSummary(endedEarly: false)
            return
        }

        transitionToSummary(endedEarly: true)
    }

    func saveMatch() async {
        guard phase == .summary, let session, let matchID, !isSaving else { return }
        isSaving = true

        // End the workout *before* building the payload: the recorder's
        // averages/totals are only final after `end()`, and the phone displays
        // exactly what this payload carries. Building it earlier shipped a
        // mid-rest heart-rate snapshot instead of the true workout average.
        let endedAt = matchActivityEndedAt ?? .now
        await workoutStartTask?.value
        workoutStartTask = nil
        try? await workoutRecorder.end(endedAt: endedAt)

        let payload = makeTransferPayload(matchID: matchID, events: session.events)
        WatchMatchStore.clearLiveMatch()
        syncService.publishCompletedMatch(payload)
        refreshPendingSyncCount()
        reset(clearLiveSession: false)
    }

    func discardMatch() async {
        guard !isSaving else { return }
        let workoutStartTask = workoutStartTask
        let endedAt = matchActivityEndedAt ?? .now
        WatchMatchStore.clearLiveMatch()
        reset(clearLiveSession: false)
        finishWorkoutInBackground(after: workoutStartTask, endedAt: endedAt)
    }

    private func finishWorkoutInBackground(after startTask: Task<Void, Never>?, endedAt: Date) {
        Task { [workoutRecorder] in
            await startTask?.value
            try? await workoutRecorder.end(endedAt: endedAt)
        }
    }

    private func refreshPendingSyncCount() {
        pendingSyncCount = WatchMatchStore.pendingCompletedMatches().count
    }

    func reset(clearLiveSession: Bool = true) {
        workoutStartTask?.cancel()
        workoutStartTask = nil
        if clearLiveSession, phase == .live {
            publishSessionEnded()
            WatchMatchStore.clearLiveMatch()
        }
        phase = .idle
        session = nil
        matchID = nil
        workoutWarning = nil
        isSaving = false
        endedEarly = false
        matchActivityEndedAt = nil
        continuation = .none
        setLineups = []
        setServeOrders = []
        decidingSideOverride = nil
        firstServer = .sideAPlayer1
        // Player names are intentionally preserved across matches so back-to-back
        // games with the same group don't require re-entry.
        loadIdleSetup()
        applyMeProfileDefaultIfNeeded()
        refreshPendingSyncCount()
    }

    var summaryScoreLine: String {
        guard let session else { return "" }
        return ScoreFormatter.matchScoreLine(in: session.state)
    }

    var summaryDuration: TimeInterval {
        if let matchActivityEndedAt {
            return matchActivityEndedAt.timeIntervalSince(startedAt)
        }
        return max(workoutRecorder.elapsedDuration, Date.now.timeIntervalSince(startedAt))
    }

    var canContinueNewSet: Bool {
        guard phase == .summary, let session, !endedEarly else { return false }
        return session.state.isMatchOver
    }

    var summaryTitle: String {
        guard let session else { return String(localized: "Summary") }
        if session.state.isMatchOver {
            return String(localized: "Match complete")
        }
        return String(localized: "Summary")
    }

    func continueNewSet() {
        guard phase == .summary, let session, session.state.isMatchOver else { return }

        // Remember the decided match so we can restore it if the user ends without
        // playing any further points.
        continuation = .pending(rules: rules, eventCount: session.events.count)

        let setsA = session.state.setsWonA
        let setsB = session.state.setsWonB
        rules.setsToWin = max(setsA, setsB) + 1
        self.session = ScoringSession(rules: rules, events: session.events)

        endedEarly = false
        matchActivityEndedAt = nil
        decidingSideOverride = nil
        phase = .live
        syncSetLineups()
        syncSetServeOrders()
        persistLiveState()
        publishSnapshot()
    }

    private func transitionToSummary(endedEarly: Bool) {
        self.endedEarly = endedEarly
        matchActivityEndedAt = .now
        phase = .summary
        publishSessionEnded()
    }

    /// A label for a serving slot: the player's name when set, else the
    /// positional slot label.
    func serverDisplayName(for slot: PlayerSlot) -> String {
        let name = slot.selection(from: playerSetup).trimmedName
        return name.isEmpty ? slot.label : name
    }

    func reservedPlayerNames(excluding excludedSlot: PlayerSlot) -> Set<String> {
        var names = Set<String>()
        for slot in PlayerSlot.allCases where slot != excludedSlot {
            let selection = slot.selection(from: playerSetup)
            let trimmed = selection.trimmedName
            if !trimmed.isEmpty {
                names.insert(trimmed)
            }
        }
        return names
    }

    func assignGuestName(to slot: PlayerSlot) {
        let reserved = reservedPlayerNames(excluding: slot)
            .union(Set(knownPlayerNames))
        let guestName = GuestPlayerNaming.nextName(avoiding: reserved)
        var setup = playerSetup
        slot.applySelection(MatchPlayerSlotSelection(name: guestName), to: &setup)
        playerSetup = setup
    }

    func applyMeProfileDefaultIfNeeded() {
        guard phase == .idle, let meProfile else { return }

        let slot = meProfile.preferredSlot
        firstServer = slot
        let current = slot.selection(from: playerSetup)
        guard !current.hasContent else { return }

        var setup = playerSetup
        slot.applySelection(MatchPlayerSlotSelection(name: meProfile.displayName), to: &setup)
        playerSetup = setup
    }

    private func loadIdleSetup() {
        let rules = MatchRulesPreferences.load()
        let values = MatchRulesPreferences.formValues(from: rules)
        bestOfSets = values.bestOfSets
        gamePointStyle = values.gamePointStyle
        setTieBreak = values.setTieBreak
        finalSetTieBreak = values.finalSetTieBreak
        self.rules = rules
    }

    private func buildRules() -> MatchRules {
        MatchRulesPreferences.makeRules(
            bestOfSets: bestOfSets,
            gamePointStyle: gamePointStyle,
            setTieBreak: setTieBreak,
            finalSetTieBreak: finalSetTieBreak
        )
    }

    private func publishSnapshot() {
        guard phase == .live, let session, let matchID else { return }

        let serve = currentServe
        let snapshot = LiveScoreSnapshot(
            matchID: matchID,
            state: session.state,
            playerNames: activePlayerNames,
            pointCount: session.events.count,
            isSessionActive: true,
            serve: serve,
            servingPlayerName: serve.map { serverDisplayName(for: $0.servingSlot) }
        )
        syncService.publishLiveScore(snapshot)
    }

    private func publishSessionEnded() {
        guard let matchID else { return }
        syncService.publishSessionEnded(matchID: matchID)
    }

    private func makeTransferPayload(matchID: UUID, events: [PointEvent]) -> MatchTransferPayload {
        MatchTransferPayload(
            id: matchID,
            startedAt: startedAt,
            endedAt: matchActivityEndedAt ?? .now,
            rules: rules,
            events: events,
            playerNames: activePlayerNames,
            averageHeartRate: workoutRecorder.averageHeartRate,
            activeEnergyKilocalories: workoutRecorder.activeEnergyKilocalories,
            distanceMeters: workoutRecorder.distanceMeters,
            setLineups: setLineups,
            setServeOrders: setServeOrders
        )
    }
}
