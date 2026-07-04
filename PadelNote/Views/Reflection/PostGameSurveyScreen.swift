import PadelCore
import SwiftData
import SwiftUI

/// Hosts the post-game reflection form with Save / Skip actions. Shared by the
/// end-of-game step after a completed match (shown inline; `autoDismiss == false`)
/// and the "Reflect / Edit" entry pushed from `MatchDetailView`
/// (`autoDismiss == true`, so it pops itself on finish).
struct PostGameSurveyScreen: View {
    let match: Match
    /// When true, the screen pops itself (push presentation) after finishing.
    var autoDismiss: Bool = false
    /// Called after the player saves or skips.
    var onFinish: () -> Void = {}

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var draft: PostGameSurvey

    init(match: Match, autoDismiss: Bool = false, onFinish: @escaping () -> Void = {}) {
        self.match = match
        self.autoDismiss = autoDismiss
        self.onFinish = onFinish
        _draft = State(initialValue: match.survey ?? PostGameSurvey())
    }

    var body: some View {
        Form {
            Section {
                Text(String(localized: "A quick reflection while the game is fresh — every match is a note."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            PostGameSurveyForm(draft: $draft)

            Section {
                Button {
                    save()
                } label: {
                    Text(String(localized: "Save reflection"))
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .disabled(draft.isEmpty)
                .accessibilityLabel(String(localized: "Save reflection"))
            }
        }
        .navigationTitle(String(localized: "How was the game?"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "Skip")) {
                    finish()
                }
                .accessibilityLabel(String(localized: "Skip reflection"))
            }
        }
    }

    private func save() {
        guard !draft.isEmpty else {
            finish()
            return
        }
        var submitted = draft
        submitted.completedAt = .now
        MatchPersistence.saveSurvey(context: modelContext, match: match, survey: submitted)
        finish()
    }

    private func finish() {
        onFinish()
        if autoDismiss {
            dismiss()
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        PostGameSurveyScreen(
            match: Match(
                startedAt: .now.addingTimeInterval(-3600),
                endedAt: .now,
                rules: .default,
                completedSets: [SetScore(gamesA: 6, gamesB: 4)],
                winner: .a
            ),
            autoDismiss: true
        )
    }
    .modelContainer(PreviewData.container)
}
#endif
