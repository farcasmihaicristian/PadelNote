import Foundation
import SwiftData

public enum HistoryDriveImporter {
    private static let importVersionKey = "historyDriveImportVersion"
    public static let currentImportVersion = 2

    @MainActor
    public static func replaceAllHistory(context: ModelContext) throws {
        if let matches = try? context.fetch(FetchDescriptor<Match>()) {
            for match in matches {
                context.delete(match)
            }
        }

        let csv = try loadBundledCSV()
        let rows = try parseCSV(csv)
        guard rows.count > 1 else { return }

        let headers = rows[0]
        for row in rows.dropFirst() {
            guard let record = HistoryDriveRecord(headers: headers, values: row) else { continue }
            try insertMatch(record, context: context)
        }

        try context.save()
        PlayerPersistence.pruneUnreferencedPlayers(context: context)
    }

    @MainActor
    public static func importIfNeeded(context: ModelContext) {
        let storedVersion = UserDefaults.standard.integer(forKey: importVersionKey)
        guard storedVersion < currentImportVersion else { return }

        try? replaceAllHistory(context: context)
        UserDefaults.standard.set(currentImportVersion, forKey: importVersionKey)
    }

    @MainActor
    private static func insertMatch(_ record: HistoryDriveRecord, context: ModelContext) throws {
        let completedSets = record.completedSets
        guard !completedSets.isEmpty else { return }

        let setsWonA = completedSets.filter { $0.gamesA > $0.gamesB }.count
        let setsWonB = completedSets.filter { $0.gamesB > $0.gamesA }.count
        guard setsWonA != setsWonB || record.unfinishedSet != nil else { return }

        let winner: Team? = record.unfinishedSet == nil
            ? (setsWonA > setsWonB ? .a : .b)
            : nil
        let rules = MatchRules(
            setsToWin: max(setsWonA, setsWonB) + (record.unfinishedSet == nil ? 0 : 1),
            gamePointStyle: .goldenPoint
        )

        let setup = MatchPlayerSetup(
            sideAPlayer1: .init(name: record.teamAPlayers[0]),
            sideAPlayer2: .init(name: record.teamAPlayers[1]),
            sideBPlayer1: .init(name: record.teamBPlayers[0]),
            sideBPlayer2: .init(name: record.teamBPlayers[1])
        )
        let roster = PlayerPersistence.resolveRoster(context: context, setup: setup)

        let events = ImportedMatchEvents.synthesize(
            for: completedSets,
            unfinishedSet: record.unfinishedSet,
            rules: rules
        )
        let replayed = ScoringEngine.replay(events: events.map { PointEvent(team: $0) }, rules: rules)

        let match = Match(
            startedAt: record.startedAt,
            endedAt: record.endedAt,
            rules: rules,
            completedSets: completedSets,
            winner: winner,
            playerNames: setup.playerNames,
            roster: roster
        )
        context.insert(match)

        if replayed.completedSets != completedSets || replayed.winner != winner {
            match.completedSets = completedSets
            match.winner = winner
        }

        for (index, team) in events.enumerated() {
            let point = StoredPointEvent(
                sequence: index,
                team: team,
                timestamp: record.startedAt.addingTimeInterval(Double(index) * 30),
                match: match
            )
            context.insert(point)
            match.points.append(point)
        }
        match.refreshCompletionStatus()
    }

    private static func loadBundledCSV() throws -> String {
        guard let url = Bundle.module.url(forResource: "historyDrive", withExtension: "csv") else {
            throw ImportError.missingBundledCSV
        }
        return try String(contentsOf: url, encoding: .utf8)
    }

    static func parseCSV(_ text: String) throws -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        var index = text.startIndex

        while index < text.endIndex {
            let character = text[index]

            if inQuotes {
                if character == "\"" {
                    let next = text.index(after: index)
                    if next < text.endIndex, text[next] == "\"" {
                        field.append("\"")
                        index = next
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(character)
                }
            } else if character == "\"" {
                inQuotes = true
            } else if character == "," {
                row.append(field)
                field = ""
            } else if character == "\n" {
                row.append(field)
                field = ""
                if !row.allSatisfy(\.isEmpty) {
                    rows.append(row)
                }
                row = []
            } else if character != "\r" {
                field.append(character)
            }

            index = text.index(after: index)
        }

        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            if !row.allSatisfy(\.isEmpty) {
                rows.append(row)
            }
        }

        return rows
    }

    enum ImportError: Error {
        case missingBundledCSV
    }
}

private struct HistoryDriveRecord {
    let startedAt: Date
    let endedAt: Date
    let teamAPlayers: [String]
    let teamBPlayers: [String]
    let completedSets: [SetScore]
    let unfinishedSet: SetScore?

    init?(headers: [String], values: [String]) {
        guard let dateIndex = columnIndex("Date", in: headers),
              let teamAIndex = columnIndex("Team A", in: headers),
              let teamBIndex = columnIndex("Team B", in: headers),
              let dateValue = values[safe: dateIndex],
              let teamAValue = values[safe: teamAIndex],
              let teamBValue = values[safe: teamBIndex]
        else { return nil }

        let durationIndex = columnIndex("Duration in Minutes", in: headers)
        let durationMinutes = Int(values[safe: durationIndex ?? -1] ?? "") ?? 90
        guard let startedAt = Self.parseDate(dateValue) else { return nil }

        let teamAPlayers = Self.parsePlayers(teamAValue)
        let teamBPlayers = Self.parsePlayers(teamBValue)
        guard teamAPlayers.count == 2, teamBPlayers.count == 2 else { return nil }

        let setColumns = headers.enumerated().compactMap { index, header -> Int? in
            let trimmed = header.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.hasPrefix("Set ") else { return nil }
            return index
        }

        let completedSets = setColumns.compactMap { index -> SetScore? in
            guard let raw = values[safe: index]?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !raw.isEmpty
            else { return nil }
            return Self.parseCompletedSetScore(raw)
        }

        guard !completedSets.isEmpty else { return nil }
        let unfinishedSet = columnIndex("Unfinished Set", in: headers)
            .flatMap { values[safe: $0]?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .flatMap { $0.isEmpty ? nil : Self.parseSetGames($0) }

        self.startedAt = startedAt
        self.endedAt = startedAt.addingTimeInterval(TimeInterval(durationMinutes * 60))
        self.teamAPlayers = teamAPlayers
        self.teamBPlayers = teamBPlayers
        self.completedSets = completedSets
        self.unfinishedSet = unfinishedSet
    }

    private static func parseDate(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: value.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return nil
        }
        return Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: date)
    }

    private static func parsePlayers(_ value: String) -> [String] {
        value
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func parseSetGames(_ value: String) -> SetScore? {
        let parts = value.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 2,
              let gamesA = Int(parts[0]),
              let gamesB = Int(parts[1])
        else { return nil }

        return SetScore(gamesA: gamesA, gamesB: gamesB)
    }

    private static func parseCompletedSetScore(_ value: String) -> SetScore? {
        guard let score = parseSetGames(value) else { return nil }
        let leader = max(score.gamesA, score.gamesB)
        let trailer = min(score.gamesA, score.gamesB)

        guard leader >= 6 else { return nil }
        guard leader == 7 || leader - trailer >= 2 else { return nil }
        guard leader <= 7 else { return nil }

        let gamesA = score.gamesA
        let gamesB = score.gamesB
        if max(gamesA, gamesB) == 7, min(gamesA, gamesB) == 6 {
            if gamesA == 7 {
                return SetScore(gamesA: 7, gamesB: 6, tieBreakA: 7, tieBreakB: 5)
            }
            return SetScore(gamesA: 6, gamesB: 7, tieBreakA: 5, tieBreakB: 7)
        }

        return SetScore(gamesA: gamesA, gamesB: gamesB)
    }
}

private enum ImportedMatchEvents {
    static func synthesize(for sets: [SetScore], unfinishedSet: SetScore? = nil, rules: MatchRules) -> [Team] {
        var events = sets.flatMap { synthesizeSet($0, rules: rules) }
        if let unfinishedSet {
            events += games(countA: unfinishedSet.gamesA, countB: unfinishedSet.gamesB, rules: rules)
        }
        return events
    }

    private static func synthesizeSet(_ set: SetScore, rules: MatchRules) -> [Team] {
        if let tieBreakA = set.tieBreakA, let tieBreakB = set.tieBreakB {
            return sixAllGames(rules: rules)
                + tieBreakPoints(
                    winner: set.gamesA > set.gamesB ? .a : .b,
                    winnerPoints: max(tieBreakA, tieBreakB),
                    loserPoints: min(tieBreakA, tieBreakB),
                    rules: rules
                )
        }

        return games(countA: set.gamesA, countB: set.gamesB, rules: rules)
    }

    private static func games(countA: Int, countB: Int, rules: MatchRules) -> [Team] {
        var events: [Team] = []
        let leader: Team = countA >= countB ? .a : .b
        let trailer: Team = leader == .a ? .b : .a
        let leaderCount = max(countA, countB)
        let trailerCount = min(countA, countB)

        // Build the score without letting a completed-set score finish early
        // (e.g. 6-3 must be reached as 0-3 -> 6-3, not 6-0 -> 6-3).
        for _ in 0..<trailerCount { events += gamePoints(for: trailer, rules: rules) }
        for _ in 0..<leaderCount { events += gamePoints(for: leader, rules: rules) }
        return events
    }

    private static func sixAllGames(rules: MatchRules) -> [Team] {
        var events: [Team] = []
        for _ in 0..<5 {
            events += gamePoints(for: .a, rules: rules)
            events += gamePoints(for: .b, rules: rules)
        }
        events += gamePoints(for: .a, rules: rules)
        events += gamePoints(for: .b, rules: rules)
        return events
    }

    private static func gamePoints(for team: Team, rules: MatchRules) -> [Team] {
        switch rules.gamePointStyle {
        case .goldenPoint:
            return Array(repeating: team, count: 4)
        case .advantage, .starPoint:
            return [team, team, team, team]
        }
    }

    private static func tieBreakPoints(
        winner: Team,
        winnerPoints: Int,
        loserPoints: Int,
        rules: MatchRules
    ) -> [Team] {
        let loser: Team = winner == .a ? .b : .a
        var events: [Team] = []
        var winnerCount = 0
        var loserCount = 0

        while winnerCount < winnerPoints || loserCount < loserPoints {
            if winnerCount <= loserCount, winnerCount < winnerPoints {
                events.append(winner)
                winnerCount += 1
            } else if loserCount < loserPoints {
                events.append(loser)
                loserCount += 1
            } else {
                break
            }
        }

        return events
    }
}

private func columnIndex(_ name: String, in headers: [String]) -> Int? {
    headers.firstIndex {
        $0.trimmingCharacters(in: .whitespacesAndNewlines)
            .caseInsensitiveCompare(name) == .orderedSame
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
