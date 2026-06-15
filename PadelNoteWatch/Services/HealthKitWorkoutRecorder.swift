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

    var elapsedDuration: TimeInterval {
        Date.now.timeIntervalSince(startedAt)
    }

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            authorizationDenied = true
            return
        }

        let typesToShare: Set<HKSampleType> = [HKObjectType.workoutType()]
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.workoutType(),
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!
        ]

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

        startedAt = .now
        heartRateSamples = []
        averageHeartRate = nil
        activeEnergyKilocalories = nil
        distanceMeters = nil
        savedToHealth = false
        hasEnded = false

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .tennis
        configuration.locationType = .indoor

        let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
        let builder = session.associatedWorkoutBuilder()
        builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)

        session.delegate = self
        builder.delegate = self

        self.session = session
        self.builder = builder

        session.startActivity(with: startedAt)
        try await builder.beginCollection(at: startedAt)
        try await builder.addMetadata([
            HKMetadataKeyWorkoutBrandName: "Padel",
            "sport": "padel"
        ])
    }

    func end(endedAt: Date = .now) async throws {
        guard let session, let builder else { return }
        guard !hasEnded else { return }
        hasEnded = true

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

        session.end()
        self.session = nil
        self.builder = nil
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

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {}
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

enum WorkoutRecorderError: LocalizedError {
    case healthDataUnavailable

    var errorDescription: String? {
        switch self {
        case .healthDataUnavailable:
            String(localized: "Health data is not available on this device.")
        }
    }
}
