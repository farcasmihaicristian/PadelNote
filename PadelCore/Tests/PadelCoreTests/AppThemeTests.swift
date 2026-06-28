import Foundation
import Testing
@testable import PadelCore

@Test func appThemeCatalogContainsTwentyUniqueThemes() {
    let themes = AppThemeCatalog.all
    #expect(themes.count == 20)
    #expect(Set(themes.map(\.id)).count == themes.count)
    #expect(AppThemeCatalog.default.id == "midnightEmerald")
}

@Test func appThemeCatalogHexValuesAreValid() throws {
    let regex = try Regex("^#[0-9A-Fa-f]{6}$")

    for theme in AppThemeCatalog.all {
        let colors = [
            theme.team1Top,
            theme.team1Bottom,
            theme.team2Top,
            theme.team2Bottom,
            theme.serve,
        ]
        for color in colors {
            #expect(color.wholeMatch(of: regex) != nil)
        }
    }
}

@Test func appThemeCatalogLooksUpThemeOrFallsBackToDefault() {
    #expect(AppThemeCatalog.theme(withID: "oceanBreeze").name == "Ocean Breeze")
    #expect(AppThemeCatalog.theme(withID: "missing").id == AppThemeCatalog.default.id)
    #expect(AppThemeCatalog.theme(withID: nil).id == AppThemeCatalog.default.id)
}

@Test func appThemePreferencesRoundTripAndDefault() {
    let defaults = UserDefaults.standard
    let previous = AppThemePreferences.loadID()
    defer { AppThemePreferences.saveID(previous) }

    AppThemePreferences.saveID(nil)
    #expect(AppThemePreferences.load().id == AppThemeCatalog.default.id)

    AppThemePreferences.save(AppThemeCatalog.theme(withID: "cobaltStrike"))
    #expect(AppThemePreferences.loadID() == "cobaltStrike")
    #expect(AppThemePreferences.load().name == "Cobalt Strike")

    defaults.set("unknown-theme", forKey: "selectedAppThemeID")
    #expect(AppThemePreferences.load().id == AppThemeCatalog.default.id)
}
