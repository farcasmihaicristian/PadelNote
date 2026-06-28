import AuthenticationServices
import PadelCore
import SwiftData
import SwiftUI

@Observable
@MainActor
final class CurrentUserStore {
    private(set) var currentUser: AppUser?
    private(set) var mePlayer: Player?
    private(set) var isSigningIn = false
    private(set) var authErrorMessage: String?
    private(set) var pendingPastMatchLinkCount = 0

    private var modelContext: ModelContext?

    var isSignedIn: Bool {
        currentUser != nil && mePlayer != nil
    }

    func activate(modelContext: ModelContext) {
        self.modelContext = modelContext
        restoreSession()
    }

    func restoreSession() {
        guard let modelContext, let accountID = AuthSessionStore.loadAccountID() else { return }

        if accountID.hasPrefix("local.") || !AuthCapabilities.supportsSignInWithApple {
            loadStoredUser(accountID: accountID, context: modelContext)
            return
        }

        ASAuthorizationAppleIDProvider().getCredentialState(forUserID: accountID) { state, _ in
            Task { @MainActor in
                // Ignore a stale result if the session changed (sign out / switch
                // account) while the async credential check was in flight.
                guard AuthSessionStore.loadAccountID() == accountID else { return }
                switch state {
                case .authorized:
                    self.loadStoredUser(accountID: accountID, context: modelContext)
                default:
                    self.signOut()
                }
            }
        }
    }

    func handleSignInResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                authErrorMessage = String(localized: "Sign in with Apple did not return a valid credential.")
                return
            }
            completeSignIn(with: credential)
        case .failure(let error):
            if (error as NSError).code == ASAuthorizationError.canceled.rawValue {
                return
            }
            authErrorMessage = error.localizedDescription
        }
    }

    func completeSignIn(with credential: ASAuthorizationAppleIDCredential) {
        guard let modelContext else { return }

        isSigningIn = true
        authErrorMessage = nil
        defer { isSigningIn = false }

        finishSignIn(
            accountID: credential.user,
            displayName: SignInWithAppleCredential.displayName(from: credential),
            email: credential.email,
            context: modelContext
        )
    }

    func signInWithLocalProfile(displayName: String) {
        guard let modelContext else { return }

        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            authErrorMessage = String(localized: "Enter your name to set up your profile.")
            return
        }

        isSigningIn = true
        authErrorMessage = nil
        defer { isSigningIn = false }

        let accountID = AuthSessionStore.loadAccountID() ?? "local.\(UUID().uuidString)"
        finishSignIn(
            accountID: accountID,
            displayName: trimmed,
            email: nil,
            context: modelContext
        )
    }

    func signOut() {
        guard let modelContext, let user = currentUser else {
            AuthSessionStore.clear()
            currentUser = nil
            mePlayer = nil
            pendingPastMatchLinkCount = 0
            return
        }

        UserAccountPersistence.signOut(context: modelContext, user: user)
        AuthSessionStore.clear()
        currentUser = nil
        mePlayer = nil
        pendingPastMatchLinkCount = 0
    }

    func linkPastMatches() {
        guard let modelContext, let mePlayer else { return }
        UserAccountPersistence.linkPastMatches(to: mePlayer, context: modelContext)
        pendingPastMatchLinkCount = 0
        MeProfilePreferences.markPastMatchLinkOffered()
    }

    func dismissPastMatchLinkOffer() {
        pendingPastMatchLinkCount = 0
        MeProfilePreferences.markPastMatchLinkOffered()
    }

    private func finishSignIn(
        accountID: String,
        displayName: String?,
        email: String?,
        context: ModelContext
    ) {
        let user = UserAccountPersistence.signIn(
            context: context,
            appleUserID: accountID,
            displayName: displayName,
            email: email
        )
        AuthSessionStore.saveAccountID(accountID)
        currentUser = user
        mePlayer = PlayerPersistence.fetchPlayer(id: user.playerID, context: context)
        refreshPastMatchLinkOffer(using: context)
    }

    private func loadStoredUser(accountID: String, context: ModelContext) {
        if let user = UserAccountPersistence.fetchUser(appleUserID: accountID, context: context),
           let player = PlayerPersistence.fetchPlayer(id: user.playerID, context: context) {
            currentUser = user
            mePlayer = player
            player.isOwnedByCurrentUser = true
            try? context.save()
        } else {
            AuthSessionStore.clear()
            currentUser = nil
            mePlayer = nil
        }
    }

    private func refreshPastMatchLinkOffer(using modelContext: ModelContext) {
        guard let mePlayer, !MeProfilePreferences.hasOfferedPastMatchLink else {
            pendingPastMatchLinkCount = 0
            return
        }
        pendingPastMatchLinkCount = UserAccountPersistence.linkablePastMatchCount(
            for: mePlayer,
            context: modelContext
        )
    }
}

enum SignInWithAppleCredential {
    static func displayName(from credential: ASAuthorizationAppleIDCredential) -> String? {
        guard let fullName = credential.fullName else { return nil }
        let formatted = PersonNameComponentsFormatter().string(from: fullName)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return formatted.isEmpty ? nil : formatted
    }
}
