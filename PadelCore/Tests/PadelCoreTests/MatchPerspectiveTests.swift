import Foundation
import Testing
@testable import PadelCore

private let meID = UUID()

private func roster(meAt slot: PlayerSlot) -> MatchRoster {
    func entry(_ s: PlayerSlot, _ name: String) -> MatchPlayerRosterEntry {
        MatchPlayerRosterEntry(id: s == slot ? meID : UUID(), name: name)
    }
    return MatchRoster(
        sideA: [entry(.sideAPlayer1, "A1"), entry(.sideAPlayer2, "A2")],
        sideB: [entry(.sideBPlayer1, "B1"), entry(.sideBPlayer2, "B2")]
    )
}

@Test func perspectiveFromBottomRightFacesTopLeft() throws {
    let perspective = try #require(MatchPerspective(roster: roster(meAt: .sideAPlayer1), mePlayerID: meID))
    #expect(perspective.partnerSlot == .sideAPlayer2)
    #expect(perspective.acrossSlot == .sideBPlayer2)
    #expect(perspective.diagonalSlot == .sideBPlayer1)
}

@Test func perspectiveFromTopLeftFacesBottomRight() throws {
    let perspective = try #require(MatchPerspective(roster: roster(meAt: .sideBPlayer2), mePlayerID: meID))
    #expect(perspective.myTeam == .b)
    #expect(perspective.partnerSlot == .sideBPlayer1)
    #expect(perspective.acrossSlot == .sideAPlayer1)
    #expect(perspective.diagonalSlot == .sideAPlayer2)
}

@Test func perspectiveFallsBackToNameMatch() throws {
    let unlinked = MatchRoster(
        sideA: [.init(name: "Alex"), .init(name: "Maria")],
        sideB: [.init(name: " mihai "), .init(name: "Dana")]
    )
    let perspective = try #require(MatchPerspective(roster: unlinked, mePlayerID: meID, meName: "Mihai"))
    #expect(perspective.mySlot == .sideBPlayer1)
}

@Test func perspectiveIsNilWhenMeNotInMatch() {
    let unlinked = MatchRoster(sideA: [.init(name: "Alex"), .init(name: "Maria")])
    #expect(MatchPerspective(roster: unlinked, mePlayerID: meID, meName: "Mihai") == nil)
    #expect(MatchPerspective(roster: unlinked, mePlayerID: nil, meName: nil) == nil)
}

@Test func courtDiagramPlacesAcrossOpponentDirectlyAboveMe() throws {
    for slot in PlayerSlot.allCases {
        let perspective = MatchPerspective(mySlot: slot)
        let rows = CourtDiagramLayout.rows(bottomTeam: perspective.myTeam)
        let column = try #require(rows.bottom.firstIndex(of: slot))
        #expect(rows.top[column] == perspective.acrossSlot)
    }
}
