import PadelCore
import SwiftData
import SwiftUI

/// A `MatchDetailView` section that shows the saved post-game reflection
/// overview (read-only) or, when none exists, an entry point to record one.
/// Works for every match — including Watch-scored ones, which never see the
/// end-of-game survey step on the phone.
struct MatchReflectionSection: View {
    @Bindable var match: Match

    var body: some View {
        Section(String(localized: "Reflection")) {
            if match.hasSurvey, let survey = match.survey {
                Text(survey.overviewHeadline)
                    .font(.headline)
                    .accessibilityLabel(survey.overviewHeadline)

                ForEach(survey.overviewDetailLines()) { line in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(line.title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(line.body)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(String(localized: "\(line.title): \(line.body)"))
                }

                NavigationLink {
                    PostGameSurveyScreen(match: match, autoDismiss: true)
                } label: {
                    Text(String(localized: "Edit reflection"))
                }
                .accessibilityLabel(String(localized: "Edit reflection"))
            } else {
                NavigationLink {
                    PostGameSurveyScreen(match: match, autoDismiss: true)
                } label: {
                    Label(String(localized: "Reflect on this game"), systemImage: "square.and.pencil")
                }
                .accessibilityLabel(String(localized: "Reflect on this game"))
            }
        }
    }
}
