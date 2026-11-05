import Testing
@testable import PadelCore

@Test func reviewPromptWaitsForMinimumCompletedMatches() {
    #expect(!ReviewPromptPolicy.shouldPrompt(completedMatchCount: 2, currentVersion: "1.0 (8)", lastPromptedVersion: nil))
    #expect(ReviewPromptPolicy.shouldPrompt(completedMatchCount: 3, currentVersion: "1.0 (8)", lastPromptedVersion: nil))
}

@Test func reviewPromptShowsOncePerVersion() {
    #expect(!ReviewPromptPolicy.shouldPrompt(completedMatchCount: 10, currentVersion: "1.0 (8)", lastPromptedVersion: "1.0 (8)"))
    #expect(ReviewPromptPolicy.shouldPrompt(completedMatchCount: 10, currentVersion: "1.1 (9)", lastPromptedVersion: "1.0 (8)"))
}
