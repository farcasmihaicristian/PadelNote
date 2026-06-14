import Foundation
import SwiftData

public enum PlayerPersistence {
    public static func normalizeName(_ name: String) -> String {
        name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
    }

    @MainActor
    public static func findOrCreatePlayer(
        context: ModelContext,
        displayName: String
    ) -> Player {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = normalizeName(trimmed)
        let normalizedCopy = normalized

        var descriptor = FetchDescriptor<Player>(
            predicate: #Predicate { $0.normalizedName == normalizedCopy }
        )
        descriptor.fetchLimit = 1

        if let existing = try? context.fetch(descriptor).first {
            return existing
        }

        let player = Player(displayName: trimmed, normalizedName: normalized)
        context.insert(player)
        return player
    }

    @MainActor
    public static func fetchPlayer(id: UUID, context: ModelContext) -> Player? {
        var descriptor = FetchDescriptor<Player>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    @MainActor
    public static func resolveSlot(
        context: ModelContext,
        name: String,
        selectedPlayerID: UUID?
    ) -> MatchPlayerRosterEntry {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return MatchPlayerRosterEntry() }

        if let selectedPlayerID,
           let player = fetchPlayer(id: selectedPlayerID, context: context) {
            return MatchPlayerRosterEntry(id: player.id, name: trimmed)
        }

        let player = findOrCreatePlayer(context: context, displayName: trimmed)
        return MatchPlayerRosterEntry(id: player.id, name: trimmed)
    }

    @MainActor
    public static func resolveRoster(
        context: ModelContext,
        setup: MatchPlayerSetup
    ) -> MatchRoster {
        let a1 = resolveSlot(context: context, name: setup.sideAPlayer1.name, selectedPlayerID: setup.sideAPlayer1.playerID)
        let a2 = resolveSlot(context: context, name: setup.sideAPlayer2.name, selectedPlayerID: setup.sideAPlayer2.playerID)
        let b1 = resolveSlot(context: context, name: setup.sideBPlayer1.name, selectedPlayerID: setup.sideBPlayer1.playerID)
        let b2 = resolveSlot(context: context, name: setup.sideBPlayer2.name, selectedPlayerID: setup.sideBPlayer2.playerID)

        return MatchRoster(
            playerA1ID: a1.id, playerA1Name: a1.name,
            playerA2ID: a2.id, playerA2Name: a2.name,
            playerB1ID: b1.id, playerB1Name: b1.name,
            playerB2ID: b2.id, playerB2Name: b2.name
        )
    }

    @MainActor
    public static func applyRoster(_ roster: MatchRoster, to match: Match) {
        let a1 = roster.sideA[safe: 0] ?? MatchPlayerRosterEntry()
        let a2 = roster.sideA[safe: 1] ?? MatchPlayerRosterEntry()
        let b1 = roster.sideB[safe: 0] ?? MatchPlayerRosterEntry()
        let b2 = roster.sideB[safe: 1] ?? MatchPlayerRosterEntry()

        match.playerA1ID = a1.id
        match.playerA1Name = a1.name
        match.playerA2ID = a2.id
        match.playerA2Name = a2.name
        match.playerB1ID = b1.id
        match.playerB1Name = b1.name
        match.playerB2ID = b2.id
        match.playerB2Name = b2.name
    }

    @MainActor
    public static func distinctDisplayNames(context: ModelContext) -> [String] {
        var names = Set<String>()

        if let players = try? context.fetch(FetchDescriptor<Player>()) {
            for player in players {
                let trimmed = player.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty, !GuestPlayerNaming.isGuestName(trimmed) {
                    names.insert(trimmed)
                }
            }
        }

        if let matches = try? context.fetch(FetchDescriptor<Match>()) {
            for match in matches {
                for entry in match.roster.allEntries {
                    guard let name = entry.name?.trimmingCharacters(in: .whitespacesAndNewlines),
                          !name.isEmpty,
                          !GuestPlayerNaming.isGuestName(name)
                    else { continue }
                    names.insert(name)
                }
            }
        }

        return names.sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
    }

    @MainActor
    public static func updateMatchPlayers(
        context: ModelContext,
        match: Match,
        setup: MatchPlayerSetup
    ) {
        let roster = resolveRoster(context: context, setup: setup)
        applyRoster(roster, to: match)
        try? context.save()
    }

    @MainActor
    public static func backfillUnlinkedMatches(context: ModelContext) {
        guard let matches = try? context.fetch(FetchDescriptor<Match>()) else { return }

        var didChange = false
        for match in matches where match.isCompleted {
            let setup = MatchPlayerSetup(
                sideAPlayer1: .init(name: match.playerA1Name ?? "", playerID: match.playerA1ID),
                sideAPlayer2: .init(name: match.playerA2Name ?? "", playerID: match.playerA2ID),
                sideBPlayer1: .init(name: match.playerB1Name ?? "", playerID: match.playerB1ID),
                sideBPlayer2: .init(name: match.playerB2Name ?? "", playerID: match.playerB2ID)
            )

            let needsLinking = [
                (match.playerA1Name, match.playerA1ID),
                (match.playerA2Name, match.playerA2ID),
                (match.playerB1Name, match.playerB1ID),
                (match.playerB2Name, match.playerB2ID),
            ].contains { name, id in
                guard let name, !name.isEmpty else { return false }
                return id == nil
            }

            guard needsLinking else { continue }

            let roster = resolveRoster(context: context, setup: setup)
            applyRoster(roster, to: match)
            didChange = true
        }

        if didChange {
            try? context.save()
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
