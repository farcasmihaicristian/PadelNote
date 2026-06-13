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
        switch match.winner {
        case .a:
            match.teamAName ?? String(localized: "Team A")
        case .b:
            match.teamBName ?? String(localized: "Team B")
        case .none:
            String(localized: "In progress")
        }
    }
}
