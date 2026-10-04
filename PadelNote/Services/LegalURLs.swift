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
}
