import Foundation

enum LegalURLs {
    /// Apple’s standard Licensed Application End User License Agreement.
    static let termsOfService = URL(
        string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"
    )!

    /// Hosted privacy policy in this repository (`docs/PRIVACY.md` on `main`).
    static let privacyPolicy = URL(
        string: "https://raw.githubusercontent.com/farcasmihaicristian/PadelNote/main/docs/PRIVACY.md"
    )!

    static let feedbackEmail = "padelnote@proton.me"

    /// Numeric Apple ID from App Store Connect → App Information. While `nil`,
    /// "Rate PadelNote" falls back to the system rating prompt.
    static let appStoreID: String? = nil

    static var writeReview: URL? {
        appStoreID.flatMap { URL(string: "https://apps.apple.com/app/id\($0)?action=write-review") }
    }
}
