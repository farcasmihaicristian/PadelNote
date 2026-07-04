import SwiftUI

private enum WatchStartFormMetrics {
    static let widthRatio: CGFloat = 0.7
    static let rowMinHeight: CGFloat = 44
}

/// Centers start-screen controls at ~70% of the watch width with room to read labels.
struct WatchStartFormLayout<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        GeometryReader { geometry in
            let formWidth = geometry.size.width * WatchStartFormMetrics.widthRatio

            ScrollView {
                VStack(alignment: .center, spacing: 10) {
                    content()
                }
                .frame(width: formWidth)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
        }
    }
}

extension View {
    func watchStartPickerRow() -> some View {
        self
            .pickerStyle(.navigationLink)
            .font(.body)
            .frame(minHeight: WatchStartFormMetrics.rowMinHeight)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    func watchStartPrimaryButton() -> some View {
        self
            .controlSize(.large)
            .frame(minHeight: WatchStartFormMetrics.rowMinHeight)
            .frame(maxWidth: .infinity)
    }
}
