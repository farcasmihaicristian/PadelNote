import SwiftUI

/// A player/partner stats row: name, a count line, and an optional win-rate
/// percentage. Shared by the Insights player list and the player-detail partner
/// list so the layout and accessibility label live in one place.
struct PlayerStatRowView: View {
    let displayName: String
    let countText: String
    let winRate: Double?
    let accessibilityLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(displayName)
                .font(.headline)

            HStack(spacing: 12) {
                Text(countText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let winRate {
                    Text(MatchFormatting.percentageText(for: winRate))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }
}
