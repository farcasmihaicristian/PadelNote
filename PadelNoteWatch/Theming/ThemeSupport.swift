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

    init(activeTheme: AppTheme = AppThemePreferences.load()) {
        self.activeTheme = activeTheme
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
}
