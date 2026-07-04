import AuthenticationServices
import PadelCore
import SwiftUI

struct AccountAuthSection: View {
    @Environment(CurrentUserStore.self) private var currentUserStore
    @State private var profileName = ""

    var body: some View {
        @Bindable var currentUserStore = currentUserStore

        Section(String(localized: "Account")) {
            if let user = currentUserStore.currentUser, let player = currentUserStore.mePlayer {
                LabeledContent(String(localized: "Signed in as")) {
                    Text(user.displayName)
                }
                LabeledContent(String(localized: "Your player profile")) {
                    Text(player.displayName)
                }

                Button(String(localized: "Sign out"), role: .destructive) {
                    currentUserStore.signOut()
                }
                .accessibilityLabel(String(localized: "Sign out"))
            } else {
                Text(accountSetupDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if AuthCapabilities.supportsSignInWithApple {
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        currentUserStore.handleSignInResult(result)
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 44)
                    .disabled(currentUserStore.isSigningIn)
                    .accessibilityLabel(String(localized: "Sign in with Apple"))
                } else {
                    TextField(String(localized: "Your name"), text: $profileName)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .accessibilityLabel(String(localized: "Your name"))

                    Button {
                        currentUserStore.signInWithLocalProfile(displayName: profileName)
                    } label: {
                        Text(String(localized: "Set up my profile"))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(currentUserStore.isSigningIn || profileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityLabel(String(localized: "Set up my profile"))
                }

                if currentUserStore.isSigningIn {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                }

                if let error = currentUserStore.authErrorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private var accountSetupDescription: String {
        if AuthCapabilities.supportsSignInWithApple {
            String(localized: "Sign in with Apple to highlight your stats and pre-fill your name on new matches.")
        } else {
            String(localized: "Set up your player profile to highlight your stats and pre-fill your name on new matches.")
        }
    }
}
