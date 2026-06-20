import Foundation

public enum MatchFormatting {
    public static func durationText(for interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        if minutes > 0 {
            return String(localized: "\(minutes)m \(seconds)s")
        }
        return String(localized: "\(seconds)s")
    }

    public static func monthTitle(for date: Date) -> String {
        date.formatted(.dateTime.month(.wide).year())
    }

    public static func dayTitle(for date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }

    public static func winnerLabel(for match: Match) -> String {
        switch match.resolvedWinner {
        case .a:
            match.teamName(for: .a)
        case .b:
            match.teamName(for: .b)
        case .none:
            match.isCompleted
                ? String(localized: "Tied")
                : String(localized: "In progress")
        }
    }

    public static func percentageText(for rate: Double) -> String {
        let percent = (rate * 100).rounded()
        return String(localized: "\(Int(percent))%")
    }

    public static func heartRateText(for bpm: Double) -> String {
        String(localized: "\(Int(bpm.rounded())) bpm")
    }

    public static func energyText(for kilocalories: Double) -> String {
        String(localized: "\(Int(kilocalories.rounded())) kcal")
    }

    public static func distanceText(for meters: Double) -> String {
        if meters >= 1000 {
            let kilometers = (meters / 1000 * 10).rounded() / 10
            return String(localized: "\(kilometers) km")
        }
        return String(localized: "\(Int(meters.rounded())) m")
    }

    public static func rolePerformanceText(for stats: RolePerformanceStats) -> String {
        guard stats.matchCount > 0 else {
            return String(localized: "No sets")
        }

        if let winRate = stats.winRate {
            return String(
                localized: "\(stats.matchCount) sets · \(percentageText(for: winRate)) wins"
            )
        }

        return String(localized: "\(stats.matchCount) sets")
    }
}
