import Foundation
import SwiftData
import Testing
@testable import PadelCore

@Test func historyDriveCSVParserHandlesQuotedTeamNames() throws {
    let csv = """
    Date,Rotation,Team A,Team B,Duration in Minutes,Set 1,Set 2,Set 3,Set 4,Set 5,Unfinished Set,Notes
    2026-03-31,2,"Sergiu, Alex","Mihai, Catalin",90,6-2,3-6,6-4,2-6,,2-4,
    """

    let rows = try HistoryDriveImporter.parseCSV(csv)
    #expect(rows.count == 2)
    #expect(rows[1][2] == "Sergiu, Alex")
    #expect(rows[1][3] == "Mihai, Catalin")
    #expect(rows[1][5] == "6-2")
    #expect(rows[1][10] == "2-4")
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
    #expect(Set(matches.compactMap(\.playerA1Name)) == Set(["Sam"]))
    #expect(matches.contains { $0.playerB2Name == "Casey" })

    let march31 = try #require(matches.first { Calendar.current.component(.month, from: $0.startedAt) == 3 })
    #expect(march31.scoreSummary == "6-2 3-6 6-4 2-6")
    #expect(march31.inProgressSetSummary == "2-4")
    #expect(march31.winner == nil)
    #expect(march31.resolvedWinner == nil)

    let may18 = try #require(matches.first {
        Calendar.current.component(.month, from: $0.startedAt) == 5
            && Calendar.current.component(.day, from: $0.startedAt) == 18
    })
    #expect(may18.scoreSummary == "6-3 6-0 6-0 6-1 6-3")
    #expect(may18.inProgressSetSummary == "4-1")
    #expect(may18.resolvedWinner == .a)
}

@MainActor
private func makeContainer() throws -> ModelContainer {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(
        for: Match.self, StoredPointEvent.self, Player.self, AppUser.self,
        configurations: configuration
    )
}
