import Foundation
import HealthKit
import PadelCore

@MainActor
final class HealthKitWorkoutRecorder: NSObject, WorkoutRecording {
    private static let minimumSaveDuration: TimeInterval = 10 * 60

    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var startedAt = Date.now
    private var heartRateSamples: [Double] = []
    private var hasEnded = false

    private(set) var isAuthorized = false
    private(set) var authorizationDenied = false
    private(set) var averageHeartRate: Double?
    private(set) var activeEnergyKilocalories: Double?
    private(set) var distanceMeters: Double?
    private(set) var savedToHealth = false

    var onRecordingError: ((String) -> Void)?

    var elapsedDuration: TimeInterval {
        Date.now.timeIntervalSince(startedAt)
    }

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            authorizationDenied = true
            return
        }

        let typesToShare: Set<HKSampleType> = [HKObjectType.workoutType()]
        var typesToRead: Set<HKObjectType> = [HKObjectType.workoutType()]
        let readIdentifiers: [HKQuantityTypeIdentifier] = [
            .heartRate, .activeEnergyBurned, .distanceWalkingRunning
        ]
        for identifier in readIdentifiers {
            if let type = HKObjectType.quantityType(forIdentifier: identifier) {
                typesToRead.insert(type)
            }
        }

        do {
            try await healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead)
            isAuthorized = true
        } catch {
            authorizationDenied = true
        }
    }

    func start() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw WorkoutRecorderError.healthDataUnavailable
        }

        // Defensively tear down any session left over from a previous match.
        if session != nil || builder != nil {
            session?.end()
            session = nil
            builder = nil
        }

        startedAt = .now
        heartRateSamples = []
        averageHeartRate = nil
        activeEnergyKilocalories = nil
        distanceMeters = nil
        savedToHealth = false
        hasEnded = false

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = WorkoutActivityPreferences.load().hkActivityType
        configuration.locationType = .indoor

        let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
        let builder = session.associatedWorkoutBuilder()
        builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)

        session.delegate = self
        builder.delegate = self

        self.session = session
        self.builder = builder

        session.startActivity(with: startedAt)
        do {
            // Cancellation can't interrupt the HealthKit awaits themselves, so
            // check around them: if the owning task was cancelled (e.g. the match
            // was abandoned mid-start), tear the session down rather than leaving
            // it running with no matching `end()`.
            try Task.checkCancellation()
            try await builder.beginCollection(at: startedAt)
            try Task.checkCancellation()
            try await builder.addMetadata([
                HKMetadataKeyWorkoutBrandName: "Padel",
                "sport": "padel"
            ])
            try Task.checkCancellation()
        } catch {
            // Roll back so a failed/cancelled start doesn't leave an orphan
            // session running.
            session.end()
            self.session = nil
            self.builder = nil
            throw error
        }
    }

    func end(endedAt: Date = .now) async throws {
        guard let session, let builder, !hasEnded else { return }
        hasEnded = true

        // Always tear down the session, even if collection/finish throws, so the
        // next match can start cleanly and no workout is left running.
        defer {
            session.end()
            self.session = nil
            self.builder = nil
        }

        let duration = endedAt.timeIntervalSince(startedAt)
        try await builder.endCollection(at: endedAt)

        if duration >= Self.minimumSaveDuration {
            try await builder.finishWorkout()
            savedToHealth = true
            if !heartRateSamples.isEmpty {
                averageHeartRate = heartRateSamples.reduce(0, +) / Double(heartRateSamples.count)
            }
        } else {
            builder.discardWorkout()
            savedToHealth = false
            averageHeartRate = nil
            activeEnergyKilocalories = nil
            distanceMeters = nil
        }
    }

    private func updateStatistics(from workoutBuilder: HKLiveWorkoutBuilder, collectedTypes: Set<HKSampleType>) {
        if let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate),
           collectedTypes.contains(heartRateType),
           let statistics = workoutBuilder.statistics(for: heartRateType),
           let latest = statistics.mostRecentQuantity() {
            let bpm = latest.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
            heartRateSamples.append(bpm)
            averageHeartRate = bpm
        }

        if let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
           collectedTypes.contains(energyType),
           let statistics = workoutBuilder.statistics(for: energyType),
           let total = statistics.sumQuantity() {
            activeEnergyKilocalories = total.doubleValue(for: .kilocalorie())
        }

        if let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning),
           collectedTypes.contains(distanceType),
           let statistics = workoutBuilder.statistics(for: distanceType),
           let total = statistics.sumQuantity() {
            distanceMeters = total.doubleValue(for: .meter())
        }
    }
}

extension HealthKitWorkoutRecorder: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {}

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        Task { @MainActor in
            onRecordingError?(
                String(localized: "Workout recording stopped. Scoring will still work.")
            )
        }
    }
}

extension HealthKitWorkoutRecorder: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    nonisolated func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        Task { @MainActor in
            updateStatistics(from: workoutBuilder, collectedTypes: collectedTypes)
        }
    }
}

private extension WorkoutActivityKind {
    var hkActivityType: HKWorkoutActivityType {
        switch self {
        case .pickleball:
            .pickleball
        case .tennis:
            .tennis
        }
    }
}

enum WorkoutRecorderError: LocalizedError {
    case healthDataUnavailable

    var errorDescription: String? {
        switch self {
        case .healthDataUnavailable:
            String(localized: "Health data is not available on this device.")
        }
    }
}
