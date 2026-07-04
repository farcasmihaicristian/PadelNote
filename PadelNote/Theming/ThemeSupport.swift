import Observation
import PadelCore
import SwiftUI

extension Color {
    init(hex: String) {
        let trimmed = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var value: UInt64 = 0
        Scanner(string: trimmed).scanHexInt64(&value)

        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255

        self.init(red: red, green: green, blue: blue)
    }
}

struct ThemePalette {
    let theme: AppTheme

    var sideAGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: theme.team1Top), Color(hex: theme.team1Bottom)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    var sideBGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: theme.team2Top), Color(hex: theme.team2Bottom)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    var sideAColor: Color { Color(hex: theme.team1Top) }
    var sideBColor: Color { Color(hex: theme.team2Top) }
    var serveColor: Color { Color(hex: theme.serve) }
    var accent: Color { serveColor }

    func gradient(for team: Team) -> LinearGradient {
        switch team {
        case .a: sideAGradient
        case .b: sideBGradient
        }
    }

    func color(for team: Team) -> Color {
        switch team {
        case .a: sideAColor
        case .b: sideBColor
        }
    }
}

@Observable
@MainActor
final class AppThemeStore {
    var activeTheme: AppTheme
    var serveIndicatorStyle: ServeIndicatorStyle

    init(
        activeTheme: AppTheme = AppThemePreferences.load(),
        serveIndicatorStyle: ServeIndicatorStyle = ServeIndicatorStylePreferences.load()
    ) {
        self.activeTheme = activeTheme
        self.serveIndicatorStyle = serveIndicatorStyle
    }

    var palette: ThemePalette {
        ThemePalette(theme: activeTheme)
    }

    func apply(_ theme: AppTheme, persist: Bool = true) {
        activeTheme = theme
        if persist {
            AppThemePreferences.save(theme)
        }
    }

    func applyThemeID(_ id: String?, persist: Bool = true) {
        apply(AppThemeCatalog.theme(withID: id), persist: persist)
    }

    func applyServeIndicatorStyle(_ style: ServeIndicatorStyle, persist: Bool = true) {
        serveIndicatorStyle = style
        if persist {
            ServeIndicatorStylePreferences.save(style)
        }
    }
}

/// Serve indicator for the `.movingBall` style: a ball that animates
/// horizontally (left ↔ right) near the serving team's net edge, tinted with
/// the theme's serve color. Uses the `tennisball.fill` SF Symbol as a
/// placeholder — swap in a custom paddle/ball image asset if desired.
struct ServeBallIndicator: View {
    let color: Color
    /// True for the bottom team (net edge is the top of its zone); false for the
    /// top team (net edge is the bottom of its zone).
    var atTopEdge: Bool

    @State private var atRight = false

    var body: some View {
        GeometryReader { proxy in
            let inset: CGFloat = 22
            let y = atTopEdge ? inset : max(inset, proxy.size.height - inset)
            Image(systemName: "tennisball.fill")
                .font(.system(size: 18))
                .foregroundStyle(color)
                .shadow(color: .black.opacity(0.5), radius: 4, y: 2)
                .position(
                    x: atRight ? max(inset, proxy.size.width - inset) : inset,
                    y: y
                )
                .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: atRight)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear { atRight = true }
    }
}
