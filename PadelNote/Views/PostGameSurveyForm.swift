import PadelCore
import SwiftUI

/// The five post-game questions, grouped by theme. Returns bare `Section`s so a
/// parent `Form` hosts them (mirrors `MatchRulesSettingsForm`).
struct PostGameSurveyForm: View {
    @Binding var draft: PostGameSurvey

    var body: some View {
        Section(String(localized: "Your game")) {
            RatingPicker(
                title: String(localized: "How did you play overall?"),
                selection: $draft.performance
            )
            RatingPicker(
                title: String(localized: "How clean was your game?"),
                selection: $draft.cleanPlay,
                accessibilityLabel: String(localized: "How clean was your game? Fewer mistakes is better.")
            )
        }

        Section {
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "What will you work on next time?"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextField(
                    String(localized: "Optional note"),
                    text: noteBinding,
                    axis: .vertical
                )
                .lineLimit(1...4)
                .accessibilityLabel(String(localized: "What will you work on next time?"))
            }
        }

        Section(String(localized: "The other players")) {
            RatingPicker(
                title: String(localized: "How well did your side play together?"),
                selection: $draft.teamwork
            )
            RatingPicker(
                title: String(localized: "How strong were the other players?"),
                selection: $draft.opponentsLevel
            )
        }
    }

    private var noteBinding: Binding<String> {
        Binding(
            get: { draft.improvementNote ?? "" },
            set: { draft.improvementNote = $0.isEmpty ? nil : $0 }
        )
    }
}

#Preview {
    struct PreviewHost: View {
        @State private var draft = PostGameSurvey()
        var body: some View {
            Form { PostGameSurveyForm(draft: $draft) }
        }
    }
    return PreviewHost()
}
