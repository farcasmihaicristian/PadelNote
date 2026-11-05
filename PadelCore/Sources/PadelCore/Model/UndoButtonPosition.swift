import Foundation

/// Which top corner of the Apple Watch live-scoring screen shows the Undo button.
public enum UndoButtonPosition: String, Codable, Sendable, CaseIterable, Identifiable {
    case left
    case right

    public static var `default`: UndoButtonPosition { .left }

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .left:
            String(localized: "Left")
        case .right:
            String(localized: "Right")
        }
    }
}
