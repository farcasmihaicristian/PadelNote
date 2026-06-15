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
    var knownPlayerNames: [String] = []
    var meProfile: WatchMeProfile?
    var healthAuthDenied = false
    var workoutWarning: String?
    var isSaving = false
    var pendingSyncCount = 0
    private var endedEarly = false
    private var matchActivityEndedAt: Date?
    private var workoutStartTask: Task<Void, Never>?
    private var hasPrepared = false
    private var rulesBeforeContinue: MatchRules?
    private var continueBaselineEventCount: Int?

    let workoutRecorder: any WorkoutRecording
    let syncService: any MatchSyncPublishing

    init(workoutRecorder: any WorkoutRecording, syncService: any MatchSyncPublishing) {
        self.workoutRecorder = workoutRecorder
        self.syncService = syncService
        configurePhoneContextSync()
        configureWorkoutErrorHandling()
    }

    private func configureWorkoutErrorHandling() {
        workoutRecorder.onRecordingError = { [weak self] message in
            self?.workoutWarning = message
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

    func toggleLeftRightSides(for team: Team) {
        var setup = playerSetup
        switch team {
        case .a:
            swap(&setup.sideAPlayer1, &setup.sideAPlayer2)
        case .b:
            swap(&setup.sideBPlayer1, &setup.sideBPlayer2)
        }
        playerSetup = setup
        publishSnapshot()
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
        workoutWarning = nil
        endedEarly = false
        matchActivityEndedAt = nil
        phase = .live
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
        rulesBeforeContinue = nil
        continueBaselineEventCount = nil

        phase = .live
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
                workoutWarning = String(localized: "Workout recording unavailable. Scoring will still work.")
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
                playerNames: activePlayerNames
            )
        )
    }

    func addPoint(for team: Team) {
        guard var session, !session.state.isMatchOver else { return }
        session.addPoint(for: team)
        self.session = session

        // A real point was played after "Continue new set", so the prior
        // completion no longer applies.
        if let baseline = continueBaselineEventCount, session.events.count > baseline {
            rulesBeforeContinue = nil
            continueBaselineEventCount = nil
        }

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
        persistLiveState()
        publishSnapshot()
    }

    func endMatchEarly() {
        guard let events = session?.events, !events.isEmpty else { return }

        // If the user tapped "Continue new set" but played no further points,
        // restore the original rules so the decided winner is preserved.
        if let baseline = continueBaselineEventCount,
           events.count == baseline,
           let originalRules = rulesBeforeContinue {
            rules = originalRules
            session = ScoringSession(rules: originalRules, events: events)
            rulesBeforeContinue = nil
            continueBaselineEventCount = nil
            transitionToSummary(endedEarly: false)
            return
        }

        transitionToSummary(endedEarly: true)
    }

    func saveMatch() async {
        guard phase == .summary, let session, let matchID, !isSaving else { return }
        isSaving = true
        defer { isSaving = false }

        do {
            await workoutStartTask?.value
            try await workoutRecorder.end(endedAt: matchActivityEndedAt ?? .now)
            if !workoutRecorder.savedToHealth {
                workoutWarning = String(localized: "Workout not saved to Apple Health — match was under 10 minutes.")
            }
        } catch {
            workoutWarning = error.localizedDescription
        }

        let payload = makeTransferPayload(matchID: matchID, events: session.events)
        WatchMatchStore.clearLiveMatch()
        syncService.publishCompletedMatch(payload)
        refreshPendingSyncCount()
        reset(clearLiveSession: false)
    }

    func discardMatch() async {
        if phase != .idle {
            await workoutStartTask?.value
            try? await workoutRecorder.end(endedAt: matchActivityEndedAt ?? .now)
        }
        WatchMatchStore.clearLiveMatch()
        reset(clearLiveSession: false)
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
        endedEarly = false
        matchActivityEndedAt = nil
        rulesBeforeContinue = nil
        continueBaselineEventCount = nil
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
        rulesBeforeContinue = rules
        continueBaselineEventCount = session.events.count

        let setsA = session.state.setsWonA
        let setsB = session.state.setsWonB
        rules.setsToWin = max(setsA, setsB) + 1
        self.session = ScoringSession(rules: rules, events: session.events)

        endedEarly = false
        matchActivityEndedAt = nil
        phase = .live
        persistLiveState()
        publishSnapshot()
    }

    private func transitionToSummary(endedEarly: Bool) {
        self.endedEarly = endedEarly
        matchActivityEndedAt = .now
        phase = .summary
        publishSessionEnded()
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

        let snapshot = LiveScoreSnapshot(
            matchID: matchID,
            state: session.state,
            playerNames: activePlayerNames,
            pointCount: session.events.count,
            isSessionActive: true
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
            distanceMeters: workoutRecorder.distanceMeters
        )
    }
}
