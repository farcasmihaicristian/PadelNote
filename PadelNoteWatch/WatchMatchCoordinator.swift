import Foundation
import PadelCore
import Observation

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
    var healthAuthDenied = false
    var workoutWarning: String?
    var isStarting = false
    var isSaving = false
    private var endedEarly = false

    let workoutRecorder: any WorkoutRecording
    let syncService: any MatchSyncPublishing

    init(workoutRecorder: any WorkoutRecording, syncService: any MatchSyncPublishing) {
        self.workoutRecorder = workoutRecorder
        self.syncService = syncService
        configureDefaultRulesSync()
    }

    private func configureDefaultRulesSync() {
        guard let publisher = syncService as? WatchConnectivityPublisher else { return }
        publisher.onDefaultRulesUpdate = { [weak self] rules in
            self?.applyDefaultRules(rules)
        }
    }

    private func applyDefaultRules(_ rules: MatchRules) {
        MatchRulesPreferences.save(rules)
        if phase == .idle {
            self.rules = rules
        }
    }

    var currentState: MatchState? {
        session?.state
    }

    func prepare() async {
        syncService.activate()
        await workoutRecorder.requestAuthorization()
        healthAuthDenied = workoutRecorder.authorizationDenied
        rules = MatchRulesPreferences.load()
    }

    func startMatch() async {
        guard !isStarting else { return }
        isStarting = true
        defer { isStarting = false }

        rules = MatchRulesPreferences.load()
        MatchRulesPreferences.save(rules)
        matchID = UUID()
        startedAt = .now
        session = ScoringSession(rules: rules)
        workoutWarning = nil
        endedEarly = false

        do {
            try await workoutRecorder.start()
        } catch {
            workoutWarning = String(localized: "Workout recording unavailable. Scoring will still work.")
        }

        phase = .live
        publishSnapshot()
    }

    func addPoint(for team: Team) {
        guard var session, !session.state.isMatchOver else { return }
        session.addPoint(for: team)
        self.session = session
        publishSnapshot()

        if session.state.isMatchOver {
            endedEarly = false
            phase = .summary
            publishSessionEnded()
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
        endedEarly = true
        phase = .summary
        publishSessionEnded()
    }

    func saveMatch() async {
        guard phase == .summary, let session, let matchID, !isSaving else { return }
        isSaving = true
        defer { isSaving = false }

        do {
            try await workoutRecorder.end()
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
            try? await workoutRecorder.end()
        }
        reset(clearLiveSession: false)
    }

    func reset(clearLiveSession: Bool = true) {
        if clearLiveSession, phase == .live {
            publishSessionEnded()
        }
        phase = .idle
        session = nil
        matchID = nil
        workoutWarning = nil
        endedEarly = false
        rules = MatchRulesPreferences.load()
    }

    var summaryScoreLine: String {
        guard let session else { return "" }
        return ScoreFormatter.matchScoreLine(in: session.state)
    }

    var summaryDuration: TimeInterval {
        max(workoutRecorder.elapsedDuration, Date.now.timeIntervalSince(startedAt))
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
        phase = .live
        publishSnapshot()
    }

    private func publishSnapshot() {
        guard phase == .live, let session, let matchID else { return }

        let snapshot = LiveScoreSnapshot(
            matchID: matchID,
            state: session.state,
            playerNames: .empty,
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
            playerNames: .empty,
            averageHeartRate: workoutRecorder.averageHeartRate,
            activeEnergyKilocalories: workoutRecorder.activeEnergyKilocalories,
            distanceMeters: workoutRecorder.distanceMeters
        )
    }
}
