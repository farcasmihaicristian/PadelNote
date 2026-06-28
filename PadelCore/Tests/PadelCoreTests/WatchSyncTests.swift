import Foundation
import Testing
@testable import PadelCore

@Test func guestNamingIncrementsAndAvoidsDuplicates() {
    let first = GuestPlayerNaming.nextName(avoiding: [])
    let second = GuestPlayerNaming.nextName(avoiding: [first])

    #expect(GuestPlayerNaming.isGuestName(first))
    #expect(GuestPlayerNaming.isGuestName(second))
    #expect(first != second)
}

@Test func guestNamingSkipsReservedNumbers() {
    let reserved = GuestPlayerNaming.displayName(number: 3)
    let name = GuestPlayerNaming.nextName(avoiding: [reserved])
    #expect(name != reserved)
}

@Test func phoneWatchSyncPayloadRoundTripsThroughCodec() throws {
    let payload = PhoneWatchSyncPayload(
        rules: MatchRules(setsToWin: 2, gamePointStyle: .starPoint),
        knownPlayerNames: ["Alex", "Maria"],
        meProfile: WatchMeProfile(displayName: "Alex", preferredSlot: .sideAPlayer1),
        workoutActivity: .tennis,
        themeID: "oceanBreeze"
    )

    let encoded = SyncPayloadCodec.encodePhoneContext(payload)
    let decoded = SyncPayloadCodec.decodePhoneContext(from: encoded)

    #expect(decoded?.rules.setsToWin == 2)
    #expect(decoded?.rules.gamePointStyle == .starPoint)
    #expect(decoded?.knownPlayerNames == ["Alex", "Maria"])
    #expect(decoded?.meProfile?.displayName == "Alex")
    #expect(decoded?.meProfile?.preferredSlot == .sideAPlayer1)
    #expect(decoded?.workoutActivity == .tennis)
    #expect(decoded?.themeID == "oceanBreeze")
}

@Test func legacyPhoneContextWithoutWorkoutActivityDecodes() throws {
    let payload = PhoneWatchSyncPayload(rules: .default)
    let encoded = SyncPayloadCodec.encodePhoneContext(payload)

    let decoded = SyncPayloadCodec.decodePhoneContext(from: encoded)
    #expect(decoded?.workoutActivity == nil)
    #expect((decoded?.workoutActivity ?? .default) == .pickleball)
    #expect(decoded?.themeID == nil)
}

@Test func filterTypingFragmentNamesRemovesPrefixOnlyEntries() {
    let names = ["A", "An", "Anon", "Anonymous", "J", "John", "Maria"]
    let filtered = PlayerPersistence.filterTypingFragmentNames(names)

    #expect(filtered.contains("Anonymous"))
    #expect(filtered.contains("John"))
    #expect(filtered.contains("Maria"))
    #expect(!filtered.contains("A"))
    #expect(!filtered.contains("An"))
    #expect(!filtered.contains("Anon"))
    #expect(!filtered.contains("J"))
}

@Test func legacyDefaultRulesDecodeAsPhoneContext() throws {
    let rules = MatchRules(setsToWin: 1, gamePointStyle: .goldenPoint)
    let encoded = [
        SyncPayloadCodec.kindKey: SyncPayloadCodec.Kind.defaultRules.rawValue,
        SyncPayloadCodec.payloadKey: try JSONEncoder().encode(rules),
    ] as [String: Any]

    let decoded = SyncPayloadCodec.decodePhoneContext(from: encoded)
    #expect(decoded?.rules.setsToWin == 1)
    #expect(decoded?.knownPlayerNames.isEmpty == true)
}
