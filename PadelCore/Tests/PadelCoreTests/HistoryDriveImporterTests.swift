import Foundation
import SwiftData
import Testing
@testable import PadelCore

@Test func historyDriveCSVParserHandlesQuotedTeamNames() throws {
    let csv = """
    Date,Rotation,Team A,Team B,Duration in Minutes,Set 1,Set 2,Set 3,Set 4,Set 5,,Notes
    2026-03-31,2,"Sergiu, Alex","Mihai, Catalin",90,6-2,3-6,6-4,2-6,2-4,,
    """

    let rows = try HistoryDriveImporter.parseCSV(csv)
    #expect(rows.count == 2)
    #expect(rows[1][2] == "Sergiu, Alex")
    #expect(rows[1][3] == "Mihai, Catalin")
    #expect(rows[1][5] == "6-2")
}

@Test @MainActor func historyDriveImporterReplacesAllMatches() throws {
    let container = try makeContainer()
    let context = container.mainContext

    _ = MatchPersistence.saveCompletedMatch(
        context: context,
        rules: MatchRules(setsToWin: 1, gamePointStyle: .goldenPoint),
        events: Array(repeating: PointEvent(team: .a), count: 4),
        startedAt: .now,
        playerSetup: MatchPlayerSetup(
            sideAPlayer1: .init(name: "Old"),
            sideAPlayer2: .init(name: "Data"),
            sideBPlayer1: .init(name: "Should"),
            sideBPlayer2: .init(name: "Go")
        )
    )

    try HistoryDriveImporter.replaceAllHistory(context: context)

    let matches = try context.fetch(FetchDescriptor<Match>())
    #expect(matches.count == 7)
    #expect(matches.allSatisfy { $0.isCompleted })
    #expect(Set(matches.compactMap(\.playerA1Name)) == Set(["Sergiu"]))
    #expect(matches.contains { $0.playerB2Name == "Catalin" })
}

@MainActor
private func makeContainer() throws -> ModelContainer {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(
        for: Match.self, StoredPointEvent.self, Player.self, AppUser.self,
        configurations: configuration
    )
}
