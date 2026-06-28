import HealthKit

enum HealthKitAuthorizationStatus: Equatable {
    case unavailable
    case notDetermined
    case authorized
    case denied
}

enum HealthKitAuthorizationChecker {
    // Apple recommends a single long-lived HKHealthStore per app rather than a
    // fresh instance on each query.
    private static let healthStore = HKHealthStore()

    static func workoutAuthorizationStatus() -> HealthKitAuthorizationStatus {
        guard HKHealthStore.isHealthDataAvailable() else { return .unavailable }

        let status = healthStore.authorizationStatus(for: HKObjectType.workoutType())

        switch status {
        case .notDetermined:
            return .notDetermined
        case .sharingAuthorized:
            return .authorized
        case .sharingDenied:
            return .denied
        @unknown default:
            return .notDetermined
        }
    }

    static func statusLabel(for status: HealthKitAuthorizationStatus) -> String {
        switch status {
        case .unavailable:
            String(localized: "Not available on this device")
        case .notDetermined:
            String(localized: "Not requested yet")
        case .authorized:
            String(localized: "Authorized")
        case .denied:
            String(localized: "Denied")
        }
    }
}
