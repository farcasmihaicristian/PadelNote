import PadelCore
import WatchKit

enum WatchHaptics {
    static func play(_ type: WKHapticType) {
        guard WatchHapticsPreferences.load() else { return }
        WKInterfaceDevice.current().play(type)
    }
}
