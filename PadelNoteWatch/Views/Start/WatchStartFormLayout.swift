import SwiftUI

/// Full-width, sectioned form for the start screen, matching the native list style used elsewhere in the watch app.
struct WatchStartFormLayout<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        Form {
            content()
        }
    }
}

extension View {
    func watchStartPickerRow() -> some View {
        self.pickerStyle(.navigationLink)
    }

    func watchStartPrimaryButton() -> some View {
        self.controlSize(.large)
    }
}
