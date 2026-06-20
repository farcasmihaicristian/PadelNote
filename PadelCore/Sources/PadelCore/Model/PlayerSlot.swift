import Foundation

public enum PlayerSlot: String, CaseIterable, Codable, Sendable, Identifiable {
    case sideAPlayer1
    case sideAPlayer2
    case sideBPlayer1
    case sideBPlayer2

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .sideAPlayer1:
            String(localized: "Bottom side · Right")
        case .sideAPlayer2:
            String(localized: "Bottom side · Left")
        case .sideBPlayer1:
            String(localized: "Top side · Right")
        case .sideBPlayer2:
            String(localized: "Top side · Left")
        }
    }

    public func selection(from setup: MatchPlayerSetup) -> MatchPlayerSlotSelection {
        switch self {
        case .sideAPlayer1: setup.sideAPlayer1
        case .sideAPlayer2: setup.sideAPlayer2
        case .sideBPlayer1: setup.sideBPlayer1
        case .sideBPlayer2: setup.sideBPlayer2
        }
    }

    public func applySelection(_ selection: MatchPlayerSlotSelection, to setup: inout MatchPlayerSetup) {
        switch self {
        case .sideAPlayer1: setup.sideAPlayer1 = selection
        case .sideAPlayer2: setup.sideAPlayer2 = selection
        case .sideBPlayer1: setup.sideBPlayer1 = selection
        case .sideBPlayer2: setup.sideBPlayer2 = selection
        }
    }
}
