import Foundation

/// When to show Apple's rating prompt: after a newly saved match once the
/// player has a few completed matches, at most once per app version.
public enum ReviewPromptPolicy {
    public static let minimumCompletedMatches = 3
    private static let lastPromptedVersionKey = "reviewPrompt.lastPromptedVersion"

    public static func shouldPrompt(
        completedMatchCount: Int,
        currentVersion: String,
        lastPromptedVersion: String?
    ) -> Bool {
        completedMatchCount >= minimumCompletedMatches && lastPromptedVersion != currentVersion
    }

    public static func lastPromptedVersion(defaults: UserDefaults = .standard) -> String? {
        defaults.string(forKey: lastPromptedVersionKey)
    }

    public static func markPrompted(version: String, defaults: UserDefaults = .standard) {
        defaults.set(version, forKey: lastPromptedVersionKey)
    }
}
