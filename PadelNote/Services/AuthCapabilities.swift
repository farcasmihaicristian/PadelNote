import Foundation

enum AuthCapabilities {
    /// Sign in with Apple requires the paid Apple Developer Program on your App ID.
    /// Set to `true` and add the Sign in with Apple entitlement when enrolled (M8).
    static let supportsSignInWithApple = false
}
