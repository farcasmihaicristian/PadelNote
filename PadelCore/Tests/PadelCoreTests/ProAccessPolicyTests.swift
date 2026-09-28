import Foundation
import Testing
@testable import PadelCore

@Test func proAccessPolicyUnlocksAllMatchesWhenPro() {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let old = now.addingTimeInterval(-60 * 24 * 60 * 60)
    #expect(ProAccessPolicy.isMatchVisible(startedAt: old, now: now, isPro: true))
}

@Test func proAccessPolicyHidesMatchesOlderThanThirtyDaysWhenFree() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let cutoff = ProAccessPolicy.freeHistoryCutoff(now: now, calendar: calendar)
    let justInside = cutoff.addingTimeInterval(1)
    let justOutside = cutoff.addingTimeInterval(-1)

    #expect(ProAccessPolicy.isMatchVisible(startedAt: justInside, now: now, isPro: false, calendar: calendar))
    #expect(!ProAccessPolicy.isMatchVisible(startedAt: justOutside, now: now, isPro: false, calendar: calendar))
}

@Test func proAccessPolicyLocksNonDefaultThemesWhenFree() {
    #expect(ProAccessPolicy.isThemeUnlocked(themeID: AppThemeCatalog.default.id, isPro: false))
    #expect(!ProAccessPolicy.isThemeUnlocked(themeID: "neonCyber", isPro: false))
    #expect(ProAccessPolicy.isThemeUnlocked(themeID: "neonCyber", isPro: true))
}

@Test func proAccessPolicyLocksMovingBallWhenFree() {
    #expect(ProAccessPolicy.isServeStyleUnlocked(style: .sideLabels, isPro: false))
    #expect(!ProAccessPolicy.isServeStyleUnlocked(style: .movingBall, isPro: false))
    #expect(ProAccessPolicy.isServeStyleUnlocked(style: .movingBall, isPro: true))
}
