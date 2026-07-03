import Foundation

/// A 1–5 self-assessment scale where **5 is always the most positive** answer,
/// so overview logic can average/threshold every rating uniformly.
public enum ReflectionRating: Int, Codable, CaseIterable, Hashable, Sendable, Identifiable {
    case poor = 1
    case belowAverage = 2
    case okay = 3
    case good = 4
    case great = 5

    public var id: Int { rawValue }

    /// Word label for pickers (avoids stars/numbers — natively VoiceOver- and
    /// Dynamic-Type-friendly).
    public var label: String {
        switch self {
        case .poor: String(localized: "Poor")
        case .belowAverage: String(localized: "Below average")
        case .okay: String(localized: "Okay")
        case .good: String(localized: "Good")
        case .great: String(localized: "Great")
        }
    }
}

/// One rendered line of the reflection overview (a labeled sentence).
public struct PostGameSurveyOverviewLine: Hashable, Sendable, Identifiable {
    public let title: String
    public let body: String

    public var id: String { "\(title)|\(body)" }

    public init(title: String, body: String) {
        self.title = title
        self.body = body
    }
}

/// A short post-game reflection: five game-related answers (performance, own
/// mistakes, the other players) plus a locally-generated overview. Stored as a
/// Codable blob on `Match`. Every field is optional so partial answers are
/// representable; `completedAt` is set only once the player submits.
public struct PostGameSurvey: Codable, Hashable, Sendable {
    /// Q1 — "How did you play overall?"
    public var performance: ReflectionRating?
    /// Q2 — "How clean was your game?" (5 = very few mistakes)
    public var cleanPlay: ReflectionRating?
    /// Q3 — "What will you work on next time?" (optional free text)
    public var improvementNote: String?
    /// Q4 — "How well did your side play together?"
    public var teamwork: ReflectionRating?
    /// Q5 — "How strong were the other players?"
    public var opponentsLevel: ReflectionRating?
    /// Set when the player submits; `nil` while still a draft / skipped.
    public var completedAt: Date?

    public init(
        performance: ReflectionRating? = nil,
        cleanPlay: ReflectionRating? = nil,
        improvementNote: String? = nil,
        teamwork: ReflectionRating? = nil,
        opponentsLevel: ReflectionRating? = nil,
        completedAt: Date? = nil
    ) {
        self.performance = performance
        self.cleanPlay = cleanPlay
        self.improvementNote = improvementNote
        self.teamwork = teamwork
        self.opponentsLevel = opponentsLevel
        self.completedAt = completedAt
    }

    // MARK: - Answer state

    private var ratings: [ReflectionRating] {
        [performance, cleanPlay, teamwork, opponentsLevel].compactMap { $0 }
    }

    private var trimmedNote: String? {
        guard let note = improvementNote?.trimmingCharacters(in: .whitespacesAndNewlines),
              !note.isEmpty
        else { return nil }
        return note
    }

    /// True when nothing was answered — treated as a skip (never submitted).
    public var isEmpty: Bool {
        ratings.isEmpty && trimmedNote == nil
    }

    /// Number of questions with an answer (ratings + a non-blank note).
    public var answeredCount: Int {
        ratings.count + (trimmedNote == nil ? 0 : 1)
    }

    private var averageRating: Double? {
        guard !ratings.isEmpty else { return nil }
        let total = ratings.reduce(0) { $0 + $1.rawValue }
        return Double(total) / Double(ratings.count)
    }

    // MARK: - Deterministic overview (no network / no AI)

    /// One-line sentiment derived from the average of the ratings present.
    public var overviewHeadline: String {
        guard let average = averageRating else {
            return String(localized: "Match reflection saved.")
        }
        switch average {
        case 4.0...:
            return String(localized: "A great game to remember.")
        case 3.0..<4.0:
            return String(localized: "A solid outing with room to grow.")
        case 2.0..<3.0:
            return String(localized: "A tough one — plenty to learn from.")
        default:
            return String(localized: "Not your day, but every game teaches something.")
        }
    }

    /// Labeled detail lines, one per answered theme, plus the verbatim note.
    /// Each body is a standalone localized sentence (no cross-language assembly).
    public func overviewDetailLines() -> [PostGameSurveyOverviewLine] {
        var lines: [PostGameSurveyOverviewLine] = []

        if let performance {
            let body: String
            switch performance.rawValue {
            case 4...5: body = String(localized: "You felt good about how you played.")
            case 3: body = String(localized: "You felt okay about how you played.")
            default: body = String(localized: "You weren't happy with how you played.")
            }
            lines.append(.init(title: String(localized: "Performance"), body: body))
        }

        if let cleanPlay {
            let body: String
            switch cleanPlay.rawValue {
            case 4...5: body = String(localized: "Your mistakes rarely hurt you.")
            case 3: body = String(localized: "Your mistakes sometimes hurt you.")
            default: body = String(localized: "Your mistakes often hurt you.")
            }
            lines.append(.init(title: String(localized: "Mistakes"), body: body))
        }

        if let teamwork {
            let body: String
            switch teamwork.rawValue {
            case 4...5: body = String(localized: "You gelled well with your partner.")
            case 3: body = String(localized: "Your partnership was steady.")
            default: body = String(localized: "Your side struggled to click.")
            }
            lines.append(.init(title: String(localized: "Teamwork"), body: body))
        }

        if let opponentsLevel {
            let body: String
            switch opponentsLevel.rawValue {
            case 4...5: body = String(localized: "You faced strong opponents.")
            case 3: body = String(localized: "You faced evenly matched opponents.")
            default: body = String(localized: "You faced beatable opponents.")
            }
            lines.append(.init(title: String(localized: "Opponents"), body: body))
        }

        if let trimmedNote {
            lines.append(.init(title: String(localized: "Next time"), body: trimmedNote))
        }

        return lines
    }
}
