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
        knownPlayerNames: ["Alex", "Maria"]
    )

    let encoded = SyncPayloadCodec.encodePhoneContext(payload)
    let decoded = SyncPayloadCodec.decodePhoneContext(from: encoded)

    #expect(decoded?.rules.setsToWin == 2)
    #expect(decoded?.rules.gamePointStyle == .starPoint)
    #expect(decoded?.knownPlayerNames == ["Alex", "Maria"])
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
