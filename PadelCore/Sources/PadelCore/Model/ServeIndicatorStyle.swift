import Foundation

/// How the serving side is shown on the live-scoring court.
public enum ServeIndicatorStyle: String, Codable, Sendable, CaseIterable, Identifiable {
    /// A static "L" / "R" chip on the serving team's service-box side.
    case sideLabels
    /// A ball that animates horizontally (left ↔ right) on the serving team's zone.
    case movingBall

    public static var `default`: ServeIndicatorStyle { .sideLabels }

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .sideLabels:
            String(localized: "Left / Right labels")
        case .movingBall:
            String(localized: "Moving ball")
        }
    }
}
