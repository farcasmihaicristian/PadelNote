import PadelCore
import SwiftUI

/// A top-down padel court with each player's name at their position.
/// `bottomTeam` is drawn nearest the viewer so the picture matches what that
/// team saw on court.
struct CourtDiagramView: View {
    @Environment(AppThemeStore.self) private var themeStore

    let bottomTeam: Team
    let name: (PlayerSlot) -> String?
    let caption: (PlayerSlot) -> String?
    var highlightedSlot: PlayerSlot?
    var onSelect: ((PlayerSlot) -> Void)?

    var body: some View {
        let rows = CourtDiagramLayout.rows(bottomTeam: bottomTeam)
        VStack(spacing: 0) {
            half(slots: rows.top, team: bottomTeam.opponent)
            net
            half(slots: rows.bottom, team: bottomTeam)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.white.opacity(0.6), lineWidth: 2)
        }
        .frame(height: 240)
    }

    private var net: some View {
        Rectangle()
            .fill(.white)
            .frame(height: 3)
            .shadow(color: .black.opacity(0.3), radius: 1, y: 1)
            .accessibilityHidden(true)
    }

    private func half(slots: [PlayerSlot], team: Team) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(slots.enumerated()), id: \.element) { index, slot in
                cell(for: slot)
                if index == 0 {
                    Rectangle()
                        .fill(.white.opacity(0.5))
                        .frame(width: 1.5)
                        .accessibilityHidden(true)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(themeStore.palette.gradient(for: team))
    }

    private func cell(for slot: PlayerSlot) -> some View {
        let isHighlighted = slot == highlightedSlot
        let displayName = name(slot) ?? String(localized: "Not set")
        let detail = caption(slot)

        return Button {
            onSelect?(slot)
        } label: {
            VStack(spacing: 3) {
                Text(displayName)
                    .font(.subheadline.weight(isHighlighted ? .bold : .semibold))
                    .foregroundStyle(.white.opacity(name(slot) == nil ? 0.6 : 1))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.black.opacity(0.35), in: Capsule())
                    .overlay {
                        Capsule()
                            .stroke(isHighlighted ? themeStore.palette.serveColor : .clear, lineWidth: 1.5)
                    }

                if let detail {
                    Text(detail)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                }
            }
            .padding(6)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(onSelect == nil)
        .accessibilityElement(children: .combine)
        .accessibilityLabel([displayName, detail].compactMap { $0 }.joined(separator: ", "))
    }
}
