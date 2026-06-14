import Foundation
import SwiftData
import Testing
@testable import PadelCore

@Test @MainActor func signInCreatesOwnedPlayerAndAppUser() throws {
    let container = try makeContainer()
    let context = container.mainContext

    let user = UserAccountPersistence.signIn(
        context: context,
        appleUserID: "apple-test-1",
        displayName: "Alex",
        email: "alex@example.com"
    )

    #expect(user.displayName == "Alex")
    #expect(user.email == "alex@example.com")

    let player = PlayerPersistence.fetchPlayer(id: user.playerID, context: context)
    #expect(player?.displayName == "Alex")
    #expect(player?.isOwnedByCurrentUser == true)
}

@Test @MainActor func signInReusesExistingAppUser() throws {
    let container = try makeContainer()
    let context = container.mainContext

    let first = UserAccountPersistence.signIn(
        context: context,
        appleUserID: "apple-test-2",
        displayName: "Alex",
        email: nil
    )
    let second = UserAccountPersistence.signIn(
        context: context,
        appleUserID: "apple-test-2",
        displayName: "Alexandra",
        email: "alex@example.com"
    )

    #expect(first.playerID == second.playerID)
    #expect(second.displayName == "Alexandra")
}

@Test @MainActor func linkPastMatchesUpdatesMatchingNameSlots() throws {
    let container = try makeContainer()
    let context = container.mainContext

    let me = Player(displayName: "Alex", normalizedName: "alex", isOwnedByCurrentUser: true)
    context.insert(me)

    let other = Player(displayName: "Chris", normalizedName: "chris")
    context.insert(other)

    let match = Match(
        startedAt: .now,
        endedAt: .now,
        rules: .default,
        roster: MatchRoster(
            playerA1ID: other.id, playerA1Name: "Alex",
            playerA2ID: nil, playerA2Name: nil,
            playerB1ID: other.id, playerB1Name: "Chris",
            playerB2ID: nil, playerB2Name: nil
        )
    )
    match.points = [StoredPointEvent(sequence: 0, team: .a, match: match)]
    context.insert(match)
    try context.save()

    let linkable = UserAccountPersistence.linkablePastMatchCount(for: me, context: context)
    #expect(linkable == 1)

    let linked = UserAccountPersistence.linkPastMatches(to: me, context: context)
    #expect(linked == 1)
    #expect(match.playerA1ID == me.id)
    #expect(match.playerB1ID == other.id)
}

@Test @MainActor func applyMeProfilePrefillsPreferredSlot() {
    var setup = MatchPlayerSetup.empty
    let player = Player(displayName: "Alex", normalizedName: "alex", isOwnedByCurrentUser: true)

    UserAccountPersistence.applyMeProfile(to: &setup, player: player, preferredSlot: .sideBPlayer2)

    #expect(setup.sideBPlayer2.name == "Alex")
    #expect(setup.sideBPlayer2.playerID == player.id)
}

@MainActor
private func makeContainer() throws -> ModelContainer {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(
        for: Match.self, StoredPointEvent.self, Player.self, AppUser.self,
        configurations: configuration
    )
}
