import Foundation
import UIKit
import WatchConnectivity

struct FeedbackDraft: Identifiable {
    enum Kind {
        case feedback
        case problem
    }

    let id = UUID()
    let recipient: String
    let subject: String
    let body: String

    var mailtoURL: URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = recipient
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body),
        ]
        return components.url
    }
}

/// Builds pre-filled feedback emails with the device details needed to
/// reproduce issues. Nothing is sent without the user tapping Send.
enum FeedbackComposer {
    static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    static var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    static func draft(_ kind: FeedbackDraft.Kind, isPro: Bool) -> FeedbackDraft {
        let subject: String
        let prompt: String
        switch kind {
        case .feedback:
            subject = String(localized: "PadelNote feedback")
            prompt = "\n\n"
        case .problem:
            subject = String(localized: "PadelNote problem report")
            prompt = String(localized: "What happened?\n\n\nWhat did you expect to happen?\n\n\nSteps to reproduce (if you know them):\n\n")
        }

        let body = """
        \(prompt)
        ---
        \(String(localized: "Please keep the details below. They help us look into your message."))
        \(diagnostics(isPro: isPro))
        """
        return FeedbackDraft(recipient: LegalURLs.feedbackEmail, subject: subject, body: body)
    }

    private static func diagnostics(isPro: Bool) -> String {
        let device = UIDevice.current
        // Diagnostic labels stay in English so support emails read the same
        // whatever language the sender uses.
        return [
            "App: \(appVersion) (\(buildNumber))",
            "\(device.systemName): \(device.systemVersion)",
            "Device: \(deviceModelIdentifier)",
            "Apple Watch: \(watchStatus)",
            "Pro: \(isPro ? "yes" : "no")",
            "Language: \(Locale.current.identifier)",
        ].joined(separator: "\n")
    }

    private static var deviceModelIdentifier: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let identifier = withUnsafeBytes(of: &systemInfo.machine) { buffer in
            String(decoding: buffer.prefix { $0 != 0 }, as: UTF8.self)
        }
        return identifier.isEmpty ? UIDevice.current.model : identifier
    }

    private static var watchStatus: String {
        guard WCSession.isSupported() else { return "not supported" }
        let session = WCSession.default
        guard session.activationState == .activated else { return "unknown" }
        guard session.isPaired else { return "not paired" }
        return session.isWatchAppInstalled ? "paired, app installed" : "paired, app not installed"
    }
}
