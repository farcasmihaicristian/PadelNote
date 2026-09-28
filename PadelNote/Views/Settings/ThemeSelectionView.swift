import PadelCore
import SwiftUI

struct ThemeSelectionView: View {
    @Environment(PhoneSyncCoordinator.self) private var syncCoordinator
    @Environment(AppThemeStore.self) private var themeStore
    @Environment(ProEntitlementStore.self) private var proStore
    @State private var showPaywall = false

    var body: some View {
        List {
            Section {
                Text(String(localized: "Pick a theme by previewing how the Apple Watch live score screen will look."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if !proStore.isPro {
                Section {
                    Button {
                        showPaywall = true
                    } label: {
                        Label(String(localized: "Unlock all themes with Pro"), systemImage: "lock.fill")
                    }
                }
            }

            Section(String(localized: "Themes")) {
                ForEach(AppThemeCatalog.all) { theme in
                    let unlocked = ProAccessPolicy.isThemeUnlocked(themeID: theme.id, isPro: proStore.isPro)
                    Button {
                        if unlocked {
                            select(theme)
                        } else {
                            showPaywall = true
                        }
                    } label: {
                        ThemePreviewRow(
                            theme: theme,
                            isSelected: theme.id == themeStore.activeTheme.id,
                            isLocked: !unlocked
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(localized: "\(theme.name) theme"))
                    .accessibilityHint(
                        !unlocked
                            ? String(localized: "Requires PadelNote Pro")
                            : theme.id == themeStore.activeTheme.id
                                ? String(localized: "Currently selected")
                                : String(localized: "Selects this app theme")
                    )
                }
            }
        }
        .navigationTitle(String(localized: "Theme"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPaywall) {
            ProPaywallView()
        }
    }

    private func select(_ theme: AppTheme) {
        AppThemePreferences.save(theme)
        themeStore.apply(theme, persist: false)
        syncCoordinator.syncPhoneContextToWatch()
    }
}

private struct ThemePreviewRow: View {
    let theme: AppTheme
    let isSelected: Bool
    var isLocked: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                SmallThemeSwatch(theme: theme)
                Text(verbatim: theme.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                if isLocked {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                } else if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color(hex: theme.serve))
                        .accessibilityHidden(true)
                }
            }

            WatchThemePreview(theme: theme)
                .opacity(isLocked ? 0.55 : 1)
        }
        .padding(.vertical, 6)
    }
}

private struct WatchThemePreview: View {
    let theme: AppTheme

    private var palette: ThemePalette {
        ThemePalette(theme: theme)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.black)

            VStack(spacing: 0) {
                teamZone(
                    gradient: palette.sideBGradient,
                    names: ("Sam", "Casey"),
                    underlineFirst: true
                )

                teamZone(
                    gradient: palette.sideAGradient,
                    names: ("Jordan", "Riley"),
                    underlineFirst: false
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .padding(5)

            VStack(spacing: 2) {
                Text(verbatim: "6-4")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(verbatim: "2-1")
                    .font(.caption.weight(.semibold))
                Text(verbatim: "40-30")
                    .font(.system(.title3, design: .rounded).weight(.bold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            Text(verbatim: "R")
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(palette.serveColor)
                .kerning(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(.black.opacity(0.5), in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(palette.serveColor, lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.5), radius: 4, y: 2)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(.leading, 18)
                .padding(.bottom, 48)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 210)
        .accessibilityHidden(true)
    }

    private func teamZone(
        gradient: LinearGradient,
        names: (String, String),
        underlineFirst: Bool
    ) -> some View {
        ZStack {
            gradient
            HStack {
                playerName(names.0, isServing: underlineFirst)
                Spacer(minLength: 24)
                playerName(names.1, isServing: !underlineFirst)
            }
            .padding(.horizontal, 20)
        }
    }

    private func playerName(_ name: String, isServing: Bool) -> some View {
        Text(name)
            .font(.caption.weight(isServing ? .bold : .semibold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .padding(.horizontal, isServing ? 8 : 0)
            .padding(.vertical, isServing ? 3 : 0)
            .background(isServing ? .black.opacity(0.5) : .clear, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(isServing ? palette.serveColor : .clear, lineWidth: 1)
            }
        .shadow(color: .black.opacity(0.25), radius: 1, y: 1)
    }
}

private struct SmallThemeSwatch: View {
    let theme: AppTheme

    var body: some View {
        Circle()
            .fill(Color(hex: theme.team1Top))
            .overlay(alignment: .trailing) {
                Rectangle()
                    .fill(Color(hex: theme.team2Top))
                    .frame(width: 12)
            }
            .clipShape(Circle())
            .overlay {
                Circle()
                    .stroke(.white.opacity(0.25), lineWidth: 1)
            }
            .frame(width: 24, height: 24)
            .accessibilityHidden(true)
    }
}

#Preview {
    NavigationStack {
        ThemeSelectionView()
    }
    .environment(PhoneSyncCoordinator(syncListener: PhoneConnectivityListener()))
    .environment(AppThemeStore())
    .environment(ProEntitlementStore())
}
