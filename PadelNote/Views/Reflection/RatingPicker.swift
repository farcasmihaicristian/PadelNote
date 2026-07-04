import PadelCore
import SwiftUI

/// A menu picker for a 1–5 `ReflectionRating` self-assessment. Word labels
/// (Poor → Great) match the app's existing picker style and are natively
/// VoiceOver- and Dynamic-Type-friendly. Includes a "Not answered" option so a
/// question can be left blank.
struct RatingPicker: View {
    let title: String
    @Binding var selection: ReflectionRating?
    var accessibilityLabel: String?

    var body: some View {
        Picker(title, selection: $selection) {
            Text(String(localized: "Not answered")).tag(ReflectionRating?.none)
            ForEach(ReflectionRating.allCases) { rating in
                Text(rating.label).tag(ReflectionRating?.some(rating))
            }
        }
        .accessibilityLabel(accessibilityLabel ?? title)
    }
}

#Preview {
    struct PreviewHost: View {
        @State private var rating: ReflectionRating?
        var body: some View {
            Form {
                RatingPicker(title: "How did you play overall?", selection: $rating)
            }
        }
    }
    return PreviewHost()
}
