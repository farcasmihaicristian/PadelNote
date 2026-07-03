import Foundation
import SwiftData
import Testing
@testable import PadelCore

// MARK: - Model round-trip & answer state

@Test func postGameSurveyCodableRoundTrips() throws {
    let survey = PostGameSurvey(
        performance: .good,
        cleanPlay: .okay,
        improvementNote: "Backhand returns",
        teamwork: .great,
        opponentsLevel: .belowAverage,
        completedAt: Date(timeIntervalSince1970: 1_000_000)
    )

    let data = try JSONEncoder().encode(survey)
    let decoded = try JSONDecoder().decode(PostGameSurvey.self, from: data)

    #expect(decoded == survey)
}

@Test func partialSurveyRoundTripsAndReportsAnswerState() throws {
    let survey = PostGameSurvey(performance: .great, improvementNote: "  ")
    let decoded = try JSONDecoder().decode(PostGameSurvey.self, from: JSONEncoder().encode(survey))

    #expect(decoded == survey)
    // Blank note doesn't count; one rating answered.
    #expect(!survey.isEmpty)
    #expect(survey.answeredCount == 1)

    let empty = PostGameSurvey()
    #expect(empty.isEmpty)
    #expect(empty.answeredCount == 0)

    let noteOnly = PostGameSurvey(improvementNote: "Serve toss")
    #expect(!noteOnly.isEmpty)
    #expect(noteOnly.answeredCount == 1)
}

// MARK: - Deterministic overview

@Test func overviewHeadlineBucketsByAverageRating() {
    let great = PostGameSurvey(performance: .great, cleanPlay: .great, teamwork: .great, opponentsLevel: .great)
    #expect(great.overviewHeadline == String(localized: "A great game to remember."))

    // (4 + 3 + 4 + 3) / 4 = 3.5
    let solid = PostGameSurvey(performance: .good, cleanPlay: .okay, teamwork: .good, opponentsLevel: .okay)
    #expect(solid.overviewHeadline == String(localized: "A solid outing with room to grow."))

    // exactly 3.0 stays "solid"
    let boundary = PostGameSurvey(performance: .okay, cleanPlay: .okay, teamwork: .okay, opponentsLevel: .okay)
    #expect(boundary.overviewHeadline == String(localized: "A solid outing with room to grow."))

    // 2.0 falls in the "tough" band
    let tough = PostGameSurvey(performance: .belowAverage, cleanPlay: .belowAverage)
    #expect(tough.overviewHeadline == String(localized: "A tough one — plenty to learn from."))

    let rough = PostGameSurvey(performance: .poor, cleanPlay: .poor)
    #expect(rough.overviewHeadline == String(localized: "Not your day, but every game teaches something."))

    // No ratings → neutral saved headline
    let noteOnly = PostGameSurvey(improvementNote: "Footwork")
    #expect(noteOnly.overviewHeadline == String(localized: "Match reflection saved."))
}

@Test func overviewDetailLinesReflectAnswersAndAppendNote() {
    let survey = PostGameSurvey(
        performance: .great,
        cleanPlay: .poor,
        improvementNote: "Backhand returns",
        teamwork: .okay,
        opponentsLevel: .great
    )

    let lines = survey.overviewDetailLines()
    // performance, mistakes, teamwork, opponents, note
    #expect(lines.count == 5)
    #expect(lines[0].body == String(localized: "You felt good about how you played."))
    #expect(lines[1].body == String(localized: "Your mistakes often hurt you."))
    #expect(lines[2].body == String(localized: "Your partnership was steady."))
    #expect(lines[3].body == String(localized: "You faced strong opponents."))
    #expect(lines[4].title == String(localized: "Next time"))
    #expect(lines[4].body == "Backhand returns")
}

@Test func overviewDetailLinesSkipUnansweredAndEmpty() {
    let partial = PostGameSurvey(performance: .good)
    #expect(partial.overviewDetailLines().count == 1)

    #expect(PostGameSurvey().overviewDetailLines().isEmpty)
}

// MARK: - Match persistence accessor

@Test @MainActor func matchSurveyAccessorRoundTripsAndTracksCompletion() throws {
    let container = try makeContainer()
    let context = container.mainContext

    let match = Match(startedAt: .now, endedAt: .now, rules: .default)
    context.insert(match)

    // Legacy / fresh match: empty blob → nil, not "has survey".
    #expect(match.survey == nil)
    #expect(!match.hasSurvey)

    // Draft (no completedAt) → present but not "completed".
    match.survey = PostGameSurvey(performance: .good)
    #expect(match.survey?.performance == .good)
    #expect(!match.hasSurvey)

    // Submitted → hasSurvey true.
    match.survey = PostGameSurvey(performance: .great, completedAt: .now)
    try context.save()
    #expect(match.hasSurvey)

    // Clearing.
    match.survey = nil
    #expect(match.survey == nil)
    #expect(!match.hasSurvey)
}

@Test @MainActor func saveSurveyPersistsOntoMatch() throws {
    let container = try makeContainer()
    let context = container.mainContext

    let match = Match(startedAt: .now, endedAt: .now, rules: .default)
    context.insert(match)

    MatchPersistence.saveSurvey(
        context: context,
        match: match,
        survey: PostGameSurvey(performance: .okay, completedAt: .now)
    )

    let matches = try context.fetch(FetchDescriptor<Match>())
    let refetched = try #require(matches.first)
    #expect(refetched.hasSurvey)
    #expect(refetched.survey?.performance == .okay)
}

@MainActor
private func makeContainer() throws -> ModelContainer {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(
        for: Match.self, StoredPointEvent.self, Player.self, AppUser.self,
        configurations: configuration
    )
}
