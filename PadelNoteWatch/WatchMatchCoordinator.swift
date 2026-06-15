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
    private var endedEarly = false
    private var matchActivityEndedAt: Date?
    private var workoutStartTask: Task<Void, Never>?

    let workoutRecorder: any WorkoutRecording
    let syncService: any MatchSyncPublishing

    init(workoutRecorder: any WorkoutRecording, syncService: any MatchSyncPublishing) {
        self.workoutRecorder = workoutRecorder
        self.syncService = syncService
        configurePhoneContextSync()
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
        syncService.activate()
        await workoutRecorder.requestAuthorization()
        healthAuthDenied = workoutRecorder.authorizationDenied
        loadIdleSetup()
        applyMeProfileDefaultIfNeeded()
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

        phase = .live
        publishSnapshot()

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

    func addPoint(for team: Team) {
        guard var session, !session.state.isMatchOver else { return }
        session.addPoint(for: team)
        self.session = session
        publishSnapshot()

        if session.state.isMatchOver {
            transitionToSummary(endedEarly: false)
        }
    }

    func undo() {
        guard var session, phase == .live else { return }
        guard session.undo() else { return }
        self.session = session
        publishSnapshot()
    }

    func endMatchEarly() {
        guard session != nil, !session!.events.isEmpty else { return }
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
        syncService.publishCompletedMatch(payload)
        reset(clearLiveSession: false)
    }

    func discardMatch() async {
        if phase != .idle {
            await workoutStartTask?.value
            try? await workoutRecorder.end(endedAt: matchActivityEndedAt ?? .now)
        }
        reset(clearLiveSession: false)
    }

    func reset(clearLiveSession: Bool = true) {
        workoutStartTask?.cancel()
        workoutStartTask = nil
        if clearLiveSession, phase == .live {
            publishSessionEnded()
        }
        phase = .idle
        session = nil
        matchID = nil
        workoutWarning = nil
        endedEarly = false
        matchActivityEndedAt = nil
        playerSetup = .empty
        loadIdleSetup()
        applyMeProfileDefaultIfNeeded()
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

        let setsA = session.state.setsWonA
        let setsB = session.state.setsWonB
        rules.setsToWin = max(setsA, setsB) + 1
        self.session = ScoringSession(rules: rules, events: session.events)

        endedEarly = false
        matchActivityEndedAt = nil
        phase = .live
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
            endedAt: .now,
            rules: rules,
            events: events,
            playerNames: activePlayerNames,
            averageHeartRate: workoutRecorder.averageHeartRate,
            activeEnergyKilocalories: workoutRecorder.activeEnergyKilocalories,
            distanceMeters: workoutRecorder.distanceMeters
        )
    }
}
