import UIKit

enum AppIconController {
    /// Asset catalog alternate app icon name (`AppIconPro.appiconset`).
    static let proIconName = "AppIconPro"

    @MainActor
    static func sync(isPro: Bool) {
        guard UIApplication.shared.supportsAlternateIcons else { return }

        let desiredName: String? = isPro ? proIconName : nil
        let current = UIApplication.shared.alternateIconName
        guard current != desiredName else { return }

        UIApplication.shared.setAlternateIconName(desiredName) { error in
            if let error {
                assertionFailure("Failed to set alternate icon: \(error.localizedDescription)")
            }
        }
    }
}
