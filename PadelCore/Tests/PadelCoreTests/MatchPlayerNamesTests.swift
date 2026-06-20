import Foundation
import Testing
@testable import PadelCore

@Test func sideLabelJoinsTwoPlayerNames() {
    let names = MatchPlayerNames(
        playerA1: "Alex",
        playerA2: "Maria",
        playerB1: "Chris",
        playerB2: "Dana"
    )

    #expect(names.sideLabel(for: .a) == "Alex · Maria")
    #expect(names.sideLabel(for: .b) == "Chris · Dana")
    #expect(names.players(for: .a) == ["Alex", "Maria"])
}

@Test func courtSideLabelOrdersPlayerTwoLeftAndPlayerOneRight() {
    let names = MatchPlayerNames(
        playerA1: "Mihai",
        playerA2: "Alex",
        playerB1: "Chris",
        playerB2: "Dana"
    )

    #expect(names.courtSideLabel(for: .a) == "Alex · Mihai")
    #expect(names.courtSideLabel(for: .b) == "Dana · Chris")
    #expect(names.playersInCourtDisplayOrder(for: .a) == ["Alex", "Mihai"])
}

@Test func sideLabelUsesSinglePlayerWhenOnlyOneNamed() {
    let names = MatchPlayerNames(playerA1: "Alex", playerA2: "", playerB1: "Chris", playerB2: "")

    #expect(names.sideLabel(for: .a) == "Alex")
    #expect(names.sideLabel(for: .b) == "Chris")
}

@Test func sideLabelFallsBackToLegacyTeamName() {
    let names = MatchPlayerNames(teamAName: "Alex & Maria", teamBName: "Chris & Dana")

    #expect(names.sideLabel(for: .a) == "Alex & Maria")
    #expect(names.sideLabel(for: .b) == "Chris & Dana")
}

@Test func sideLabelPrefersPlayerNamesOverLegacyTeamName() {
    let names = MatchPlayerNames(
        playerA1Name: "Alex",
        playerA2Name: "Maria",
        teamAName: "Old Team A"
    )

    #expect(names.sideLabel(for: Team.a) == "Alex · Maria")
}

@Test func sideLabelFallsBackToDefaultTeamLabels() {
    let names = MatchPlayerNames.empty

    #expect(names.sideLabel(for: .a) == String(localized: "Bottom Team"))
    #expect(names.sideLabel(for: .b) == String(localized: "Top Team"))
}

@Test func emptyAndWhitespaceNamesAreNormalizedAway() {
    let names = MatchPlayerNames(
        playerA1: "  Alex  ",
        playerA2: "   ",
        playerB1: "",
        playerB2: "Dana"
    )

    #expect(names.playerA1Name == "Alex")
    #expect(names.playerA2Name == nil)
    #expect(names.sideLabel(for: .a) == "Alex")
    #expect(names.sideLabel(for: .b) == "Dana")
}

@Test func matchTransferPayloadRoundTripsPlayerNames() throws {
    let payload = MatchTransferPayload(
        startedAt: .now,
        endedAt: .now,
        rules: .default,
        events: [PointEvent(team: .a)],
        playerNames: MatchPlayerNames(
            playerA1: "Alex",
            playerA2: "Maria",
            playerB1: "Chris",
            playerB2: "Dana"
        )
    )

    let data = try JSONEncoder().encode(payload)
    let decoded = try JSONDecoder().decode(MatchTransferPayload.self, from: data)

    #expect(decoded.playerNames == payload.playerNames)
}

@Test func liveScoreSnapshotDecodesLegacyTeamNamesOnly() throws {
    let json = """
    {
        "matchID": "A1B2C3D4-E5F6-7890-ABCD-EF1234567890",
        "gameScore": "40-30",
        "setGames": "3-2",
        "completedSetScores": [],
        "isMatchOver": false,
        "teamAName": "Team A",
        "teamBName": "Team B",
        "pointCount": 5,
        "updatedAt": 0,
        "isSessionActive": true
    }
    """.data(using: .utf8)!

    let snapshot = try JSONDecoder().decode(LiveScoreSnapshot.self, from: json)

    #expect(snapshot.teamLabel(for: Team.a) == "Team A")
    #expect(snapshot.teamLabel(for: Team.b) == "Team B")
    #expect(snapshot.playerA1Name == nil)
}
