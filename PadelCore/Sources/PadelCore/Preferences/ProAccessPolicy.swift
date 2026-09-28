import Foundation

/// Pure free-vs-Pro access rules. Scoring, HealthKit, and sync stay free;
/// Appearance extras and history older than 30 days require Pro.
public enum ProAccessPolicy {
    public static let freeHistoryDays = 30

    public static func freeHistoryCutoff(now: Date = .now, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: -freeHistoryDays, to: now) ?? now
    }

    public static func isMatchVisible(
        startedAt: Date,
        now: Date = .now,
        isPro: Bool,
        calendar: Calendar = .current
    ) -> Bool {
        if isPro { return true }
        return startedAt >= freeHistoryCutoff(now: now, calendar: calendar)
    }

    public static func isThemeUnlocked(themeID: String, isPro: Bool) -> Bool {
        if isPro { return true }
        return themeID == AppThemeCatalog.default.id
    }

    public static func isServeStyleUnlocked(style: ServeIndicatorStyle, isPro: Bool) -> Bool {
        if isPro { return true }
        return style == .sideLabels
    }
}
