import Foundation

public enum PlayerSlot: String, CaseIterable, Codable, Sendable, Identifiable {
    case sideAPlayer1
    case sideAPlayer2
    case sideBPlayer1
    case sideBPlayer2

    public var id: String { rawValue }

    /// The team this slot belongs to (Side A = bottom, Side B = top).
    public var team: Team {
        switch self {
        case .sideAPlayer1, .sideAPlayer2: .a
        case .sideBPlayer1, .sideBPlayer2: .b
        }
    }

    /// The partner sharing this slot's side of the court.
    public var partner: PlayerSlot {
        switch self {
        case .sideAPlayer1: .sideAPlayer2
        case .sideAPlayer2: .sideAPlayer1
        case .sideBPlayer1: .sideBPlayer2
        case .sideBPlayer2: .sideBPlayer1
        }
    }

    /// Default on-court position before any left/right swap (player 1 = right).
    public var defaultCourtSide: PlayerCourtSide {
        switch self {
        case .sideAPlayer1, .sideBPlayer1: .right
        case .sideAPlayer2, .sideBPlayer2: .left
        }
    }

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
