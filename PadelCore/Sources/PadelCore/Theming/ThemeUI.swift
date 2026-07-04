import Foundation
import Observation
import SwiftUI

public extension Color {
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

public struct ThemePalette {
    public let theme: AppTheme

    public init(theme: AppTheme) {
        self.theme = theme
    }

    public var sideAGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: theme.team1Top), Color(hex: theme.team1Bottom)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    public var sideBGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: theme.team2Top), Color(hex: theme.team2Bottom)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    public var sideAColor: Color { Color(hex: theme.team1Top) }
    public var sideBColor: Color { Color(hex: theme.team2Top) }
    public var serveColor: Color { Color(hex: theme.serve) }
    public var accent: Color { serveColor }

    public func gradient(for team: Team) -> LinearGradient {
        switch team {
        case .a: sideAGradient
        case .b: sideBGradient
        }
    }

    public func color(for team: Team) -> Color {
        switch team {
        case .a: sideAColor
        case .b: sideBColor
        }
    }
}

@Observable
@MainActor
public final class AppThemeStore {
    public var activeTheme: AppTheme
    public var serveIndicatorStyle: ServeIndicatorStyle

    public init(
        activeTheme: AppTheme = AppThemePreferences.load(),
        serveIndicatorStyle: ServeIndicatorStyle = ServeIndicatorStylePreferences.load()
    ) {
        self.activeTheme = activeTheme
        self.serveIndicatorStyle = serveIndicatorStyle
    }

    public var palette: ThemePalette {
        ThemePalette(theme: activeTheme)
    }

    public func apply(_ theme: AppTheme, persist: Bool = true) {
        activeTheme = theme
        if persist {
            AppThemePreferences.save(theme)
        }
    }

    public func applyThemeID(_ id: String?, persist: Bool = true) {
        apply(AppThemeCatalog.theme(withID: id), persist: persist)
    }

    public func applyServeIndicatorStyle(_ style: ServeIndicatorStyle, persist: Bool = true) {
        serveIndicatorStyle = style
        if persist {
            ServeIndicatorStylePreferences.save(style)
        }
    }
}

/// Serve indicator for the `.movingBall` style: a ball parked on the deuce/ad
/// box side where the server will serve. Uses the `ServeBall` asset in each
/// target's `Assets.xcassets`.
public struct ServeBallIndicator: View {
    /// True for the bottom team (net edge is the top of its zone); false for the
    /// top team (net edge is the bottom of its zone).
    public var atTopEdge: Bool
    public var serveSide: ServeSide
    public var team: Team

    public init(atTopEdge: Bool, serveSide: ServeSide, team: Team) {
        self.atTopEdge = atTopEdge
        self.serveSide = serveSide
        self.team = team
    }

    private var onRightScreenSide: Bool {
        let onRight = serveSide == .right
        return team == .a ? onRight : !onRight
    }

    public var body: some View {
        GeometryReader { proxy in
            let inset: CGFloat = 22
            let y = atTopEdge ? inset : max(inset, proxy.size.height - inset)
            Image("ServeBall")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 24, height: 24)
                .shadow(color: .black.opacity(0.5), radius: 4, y: 2)
                .position(
                    x: onRightScreenSide ? max(inset, proxy.size.width - inset) : inset,
                    y: y
                )
                .animation(.easeInOut(duration: 0.35), value: serveSide)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
