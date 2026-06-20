import Foundation

/// The Apple Health workout type recorded on Apple Watch during a match.
///
/// HealthKit has no padel type, so we let players choose the closest racquet
/// sport. The concrete `HKWorkoutActivityType` mapping lives in the Watch target
/// to keep PadelCore free of HealthKit.
public enum WorkoutActivityKind: String, Codable, Sendable, CaseIterable, Identifiable {
    case pickleball
    case tennis

    public static var `default`: WorkoutActivityKind { .pickleball }

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .pickleball:
            String(localized: "Pickleball")
        case .tennis:
            String(localized: "Tennis")
        }
    }
}
