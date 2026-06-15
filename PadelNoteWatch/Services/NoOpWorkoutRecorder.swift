import Foundation
import PadelCore

@MainActor
final class NoOpWorkoutRecorder: WorkoutRecording {
    var isAuthorized = true
    var authorizationDenied = false
    var averageHeartRate: Double?
    var activeEnergyKilocalories: Double?
    var distanceMeters: Double?
    private(set) var elapsedDuration: TimeInterval = 0
    var savedToHealth = false
    var onRecordingError: ((String) -> Void)?

    private var startedAt = Date.now

    func requestAuthorization() async {}

    func start() async throws {
        startedAt = .now
    }

    func end(endedAt: Date = .now) async throws {
        elapsedDuration = endedAt.timeIntervalSince(startedAt)
    }
}
