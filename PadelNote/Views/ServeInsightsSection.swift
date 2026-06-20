import PadelCore
import SwiftUI

struct ServeInsightsSection: View {
    let insights: PlayerInsights

    var body: some View {
        if insights.hasServeData {
            Section(String(localized: "Serve")) {
                Text(String(localized: "How you do on your own serve."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if insights.servePointsPlayed > 0 {
                    LabeledContent(String(localized: "Service points won")) {
                        Text(servePointsText)
                            .foregroundStyle(.primary)
                    }
                    .accessibilityLabel(
                        String(localized: "Service points won, \(servePointsText)")
                    )
                }

                if insights.serviceGamesPlayed > 0 {
                    LabeledContent(String(localized: "Service games held")) {
                        Text(serviceGamesText)
                            .foregroundStyle(.primary)
                    }
                    .accessibilityLabel(
                        String(localized: "Service games held, \(serviceGamesText)")
                    )
                }
            }
        }
    }

    private var servePointsText: String {
        let base = String(localized: "\(insights.servePointsWon)/\(insights.servePointsPlayed)")
        guard let rate = insights.servePointWinRate else { return base }
        return "\(base) · \(MatchFormatting.percentageText(for: rate))"
    }

    private var serviceGamesText: String {
        let base = String(localized: "\(insights.serviceGamesHeld)/\(insights.serviceGamesPlayed)")
        guard let rate = insights.serviceHoldRate else { return base }
        return "\(base) · \(MatchFormatting.percentageText(for: rate))"
    }
}
