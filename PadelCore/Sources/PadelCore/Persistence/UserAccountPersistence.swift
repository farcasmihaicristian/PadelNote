import Foundation
import SwiftData

public enum UserAccountPersistence {
    @MainActor
    public static func fetchUser(appleUserID: String, context: ModelContext) -> AppUser? {
        let idCopy = appleUserID
        var descriptor = FetchDescriptor<AppUser>(
            predicate: #Predicate { $0.appleUserID == idCopy }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    @MainActor
    public static func signIn(
        context: ModelContext,
        appleUserID: String,
        displayName: String?,
        email: String?
    ) -> AppUser {
        let trimmedName = displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedName = (trimmedName?.isEmpty == false)
            ? trimmedName!
            : String(localized: "Player")

        if let existing = fetchUser(appleUserID: appleUserID, context: context),
           let player = PlayerPersistence.fetchPlayer(id: existing.playerID, context: context) {
            if let trimmedName, !trimmedName.isEmpty {
                existing.displayName = trimmedName
                player.displayName = trimmedName
                player.normalizedName = PlayerPersistence.normalizeName(trimmedName)
            }
            existing.email = email ?? existing.email
            existing.lastSignedInAt = .now
            player.isOwnedByCurrentUser = true
            try? context.save()
            return existing
        }

        clearOwnedPlayerFlags(context: context)

        let player = Player(
            displayName: resolvedName,
            normalizedName: PlayerPersistence.normalizeName(resolvedName),
            isOwnedByCurrentUser: true
        )
        context.insert(player)

        let user = AppUser(
            appleUserID: appleUserID,
            displayName: resolvedName,
            email: email,
            playerID: player.id
        )
        context.insert(user)
        try? context.save()
        return user
    }

    @MainActor
    public static func signOut(context: ModelContext, user: AppUser) {
        if let player = PlayerPersistence.fetchPlayer(id: user.playerID, context: context) {
            player.isOwnedByCurrentUser = false
        }
        try? context.save()
    }

    @MainActor
    public static func linkablePastMatchCount(for player: Player, context: ModelContext) -> Int {
        guard let matches = try? context.fetch(FetchDescriptor<Match>()) else { return 0 }

        return matches.reduce(into: 0) { count, match in
            guard match.isCompleted else { return }
            count += linkableSlots(on: match, for: player).count
        }
    }

    @MainActor
    @discardableResult
    public static func linkPastMatches(to player: Player, context: ModelContext) -> Int {
        guard let matches = try? context.fetch(FetchDescriptor<Match>()) else { return 0 }

        var linkedSlots = 0
        for match in matches where match.isCompleted {
            linkedSlots += applyLinks(on: match, for: player)
        }

        if linkedSlots > 0 {
            try? context.save()
        }
        return linkedSlots
    }

    @MainActor
    public static func applyMeProfile(
        to setup: inout MatchPlayerSetup,
        player: Player,
        preferredSlot: PlayerSlot = MeProfilePreferences.preferredSlot()
    ) {
        var slot = preferredSlot
        slot.applySelection(
            MatchPlayerSlotSelection(name: player.displayName, playerID: player.id),
            to: &setup
        )
    }

    @MainActor
    private static func clearOwnedPlayerFlags(context: ModelContext) {
        guard let players = try? context.fetch(FetchDescriptor<Player>()) else { return }
        for player in players where player.isOwnedByCurrentUser {
            player.isOwnedByCurrentUser = false
        }
    }

    @MainActor
    private static func linkableSlots(on match: Match, for player: Player) -> [Int] {
        let slots: [(String?, UUID?)] = [
            (match.playerA1Name, match.playerA1ID),
            (match.playerA2Name, match.playerA2ID),
            (match.playerB1Name, match.playerB1ID),
            (match.playerB2Name, match.playerB2ID),
        ]

        return slots.enumerated().compactMap { index, slot in
            guard let name = slot.0, !name.isEmpty else { return nil }
            guard slot.1 != player.id else { return nil }
            guard PlayerPersistence.normalizeName(name) == player.normalizedName else { return nil }
            return index
        }
    }

    @MainActor
    private static func applyLinks(on match: Match, for player: Player) -> Int {
        let indices = linkableSlots(on: match, for: player)
        guard !indices.isEmpty else { return 0 }

        for index in indices {
            switch index {
            case 0:
                match.playerA1ID = player.id
                match.playerA1Name = match.playerA1Name ?? player.displayName
            case 1:
                match.playerA2ID = player.id
                match.playerA2Name = match.playerA2Name ?? player.displayName
            case 2:
                match.playerB1ID = player.id
                match.playerB1Name = match.playerB1Name ?? player.displayName
            case 3:
                match.playerB2ID = player.id
                match.playerB2Name = match.playerB2Name ?? player.displayName
            default:
                break
            }
        }
        return indices.count
    }
}
