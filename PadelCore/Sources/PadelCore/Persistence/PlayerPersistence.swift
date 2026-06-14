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
    public static func watchMeProfile(context: ModelContext) -> WatchMeProfile? {
        guard let players = try? context.fetch(FetchDescriptor<Player>()) else { return nil }
        guard let me = players.first(where: \.isOwnedByCurrentUser) else { return nil }

        let name = me.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }

        return WatchMeProfile(
            displayName: name,
            preferredSlot: MeProfilePreferences.preferredSlot()
        )
    }

    @MainActor
    public static func knownNamesFromMatchHistory(context: ModelContext) -> [String] {
        guard let matches = try? context.fetch(FetchDescriptor<Match>()) else { return [] }

        var names = Set<String>()
        for match in matches where match.isCompleted {
            for entry in match.roster.allEntries {
                guard let name = entry.name?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !name.isEmpty,
                      !GuestPlayerNaming.isGuestName(name)
                else { continue }
                names.insert(name)
            }
        }

        return filterTypingFragmentNames(
            names.sorted {
                $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
            }
        )
    }

    @MainActor
    public static func playersFromMatchHistory(context: ModelContext) -> [Player] {
        guard let matches = try? context.fetch(FetchDescriptor<Match>()) else { return [] }

        var ids = Set<UUID>()
        for match in matches where match.isCompleted {
            for id in match.roster.linkedPlayerIDs {
                ids.insert(id)
            }
        }

        let players = ids.compactMap { fetchPlayer(id: $0, context: context) }
        return pickerPlayers(from: players)
    }

    @MainActor
    public static func distinctDisplayNames(context: ModelContext) -> [String] {
        knownNamesFromMatchHistory(context: context)
    }

    @MainActor
    public static func pruneUnreferencedPlayers(context: ModelContext) {
        guard let matches = try? context.fetch(FetchDescriptor<Match>()),
              let players = try? context.fetch(FetchDescriptor<Player>())
        else { return }

        var referencedIDs = Set<UUID>()
        for match in matches {
            for id in match.roster.linkedPlayerIDs {
                referencedIDs.insert(id)
            }
        }

        var didDelete = false
        for player in players {
            guard !player.isOwnedByCurrentUser else { continue }
            guard !referencedIDs.contains(player.id) else { continue }
            context.delete(player)
            didDelete = true
        }

        if didDelete {
            try? context.save()
        }
    }

    public static func pickerPlayers(from players: [Player]) -> [Player] {
        let eligible = players.filter { !GuestPlayerNaming.isGuestName($0.displayName) }
        let withoutFragments = eligible.filter { player in
            !eligible.contains { other in
                other.id != player.id
                    && other.normalizedName.hasPrefix(player.normalizedName)
                    && other.normalizedName.count > player.normalizedName.count
            }
        }

        var seen = Set<String>()
        return withoutFragments
            .filter { seen.insert($0.normalizedName).inserted }
            .sorted {
                $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
    }

    public static func filterTypingFragmentNames(_ names: [String]) -> [String] {
        names.filter { name in
            let normalized = normalizeName(name)
            return !names.contains { other in
                other != name
                    && normalizeName(other).hasPrefix(normalized)
                    && normalizeName(other).count > normalized.count
            }
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
