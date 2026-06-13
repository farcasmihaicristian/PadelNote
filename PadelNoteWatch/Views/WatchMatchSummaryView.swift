import PadelCore
import SwiftUI

struct WatchMatchSummaryView: View {
    @Bindable var coordinator: WatchMatchCoordinator

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text(String(localized: "Match complete"))
                    .font(.headline)

                Text(coordinator.summaryScoreLine)
                    .font(.title3.bold())
                    .accessibilityLabel(String(localized: "Final score \(coordinator.summaryScoreLine)"))

                LabeledContent(String(localized: "Duration")) {
                    Text(MatchFormatting.durationText(for: coordinator.summaryDuration))
                }

                if let heartRate = coordinator.workoutRecorder.averageHeartRate {
                    LabeledContent(String(localized: "Avg HR")) {
                        Text(String(localized: "\(Int(heartRate.rounded())) bpm"))
                    }
                }

                if let warning = coordinator.workoutWarning {
                    Text(warning)
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }

                Button {
                    Task { await coordinator.saveMatch() }
                } label: {
                    if coordinator.isSaving {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text(String(localized: "Save"))
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(coordinator.isSaving)
                .accessibilityLabel(String(localized: "Save match"))

                Button(String(localized: "Discard")) {
                    Task { await coordinator.discardMatch() }
                }
                .buttonStyle(.bordered)
                .disabled(coordinator.isSaving)
                .accessibilityLabel(String(localized: "Discard match"))
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle(String(localized: "Summary"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    let coordinator = WatchMatchCoordinator(
        workoutRecorder: NoOpWorkoutRecorder(),
        syncService: WatchConnectivityPublisher()
    )
    coordinator.session = ScoringSession(rules: .default)
    coordinator.phase = .summary
    return WatchMatchSummaryView(coordinator: coordinator)
}
