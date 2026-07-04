import Foundation

@MainActor
protocol WorkoutRecording: AnyObject {
    var isAuthorized: Bool { get }
    var authorizationDenied: Bool { get }
    var averageHeartRate: Double? { get }
    var activeEnergyKilocalories: Double? { get }
    var distanceMeters: Double? { get }
    var elapsedDuration: TimeInterval { get }

    /// Invoked when the underlying workout session fails after it has started.
    var onRecordingError: ((String) -> Void)? { get set }

    func requestAuthorization() async
    func start() async throws
    func end(endedAt: Date) async throws
}
