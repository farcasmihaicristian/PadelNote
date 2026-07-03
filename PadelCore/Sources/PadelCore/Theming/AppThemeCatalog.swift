public enum AppThemeCatalog {
    public static let all: [AppTheme] = [
        AppTheme(id: "midnightEmerald", name: "Midnight Emerald", team1Top: "#5E56D6", team1Bottom: "#302EA3", team2Top: "#30D158", team2Bottom: "#158A30", serve: "#FF9F0A"),
        AppTheme(id: "cupertinoSunset", name: "Cupertino Sunset", team1Top: "#FF2D55", team1Bottom: "#B30E31", team2Top: "#FF9500", team2Bottom: "#B36400", serve: "#FFD60A"),
        AppTheme(id: "oceanBreeze", name: "Ocean Breeze", team1Top: "#5AC8FA", team1Bottom: "#1D749B", team2Top: "#A2E6C8", team2Bottom: "#4A9E7A", serve: "#FFCC00"),
        AppTheme(id: "berryFrost", name: "Berry Frost", team1Top: "#AF52DE", team1Bottom: "#641E96", team2Top: "#0A84FF", team2Bottom: "#0050B4", serve: "#30D158"),
        AppTheme(id: "graphiteTitanium", name: "Graphite Titanium", team1Top: "#8E8E93", team1Bottom: "#48484A", team2Top: "#46464B", team2Bottom: "#1C1C1E", serve: "#FF9F0A"),
        AppTheme(id: "lavenderDawn", name: "Lavender Dawn", team1Top: "#C8B4FA", team1Bottom: "#785AC8", team2Top: "#FFCC99", team2Bottom: "#C8783C", serve: "#FF3B30"),
        AppTheme(id: "candyApple", name: "Candy Apple", team1Top: "#FF3B30", team1Bottom: "#B4140A", team2Top: "#0A84FF", team2Bottom: "#0046A0", serve: "#FFD60A"),
        AppTheme(id: "neonCyber", name: "Neon Cyber", team1Top: "#FF00FF", team1Bottom: "#960096", team2Top: "#00FFFF", team2Bottom: "#009696", serve: "#39FF14"),
        AppTheme(id: "aquaMarine", name: "Aqua Marine", team1Top: "#009688", team1Bottom: "#00645A", team2Top: "#40E0D0", team2Bottom: "#1EA096", serve: "#FFCC00"),
        AppTheme(id: "solarFlare", name: "Solar Flare", team1Top: "#FFCC00", team1Bottom: "#C89600", team2Top: "#FF3B30", team2Bottom: "#B4140A", serve: "#FFFFFF"),
        AppTheme(id: "ultraAction", name: "Ultra Action", team1Top: "#0A0A32", team1Bottom: "#05051E", team2Top: "#FF6900", team2Bottom: "#C84B00", serve: "#FFFFFF"),
        AppTheme(id: "deepSpace", name: "Deep Space", team1Top: "#1E003C", team1Bottom: "#0F001E", team2Top: "#00143C", team2Bottom: "#000A1E", serve: "#00FFFF"),
        AppTheme(id: "cherryBlossom", name: "Cherry Blossom", team1Top: "#FFB7C5", team1Bottom: "#C87385", team2Top: "#C8DCD7", team2Bottom: "#829691", serve: "#FF6B81"),
        AppTheme(id: "arcticIce", name: "Arctic Ice", team1Top: "#B4F0FF", team1Bottom: "#5BB4C8", team2Top: "#C8D2DC", team2Bottom: "#78828C", serve: "#007AFF"),
        AppTheme(id: "sunsetBoulevard", name: "Sunset Boulevard", team1Top: "#641478", team1Bottom: "#460A5A", team2Top: "#FF5000", team2Bottom: "#C83200", serve: "#FFCC00"),
        AppTheme(id: "monochromeOled", name: "Monochrome OLED", team1Top: "#646464", team1Bottom: "#3C3C3C", team2Top: "#B4B4B4", team2Bottom: "#787878", serve: "#FFFFFF"),
        AppTheme(id: "goldenHour", name: "Golden Hour", team1Top: "#FFD700", team1Bottom: "#A58200", team2Top: "#FF7F50", team2Bottom: "#DC4614", serve: "#FFFFFF"),
        AppTheme(id: "forestCanopy", name: "Forest Canopy", team1Top: "#0A5A28", team1Bottom: "#053C19", team2Top: "#96E632", team2Bottom: "#5A960A", serve: "#FFFFFF"),
        AppTheme(id: "cobaltStrike", name: "Cobalt Strike", team1Top: "#0047AB", team1Bottom: "#002878", team2Top: "#DC143C", team2Bottom: "#A00A28", serve: "#FFD700"),
        AppTheme(id: "peachFuzz", name: "Peach Fuzz", team1Top: "#FFCCBC", team1Bottom: "#D28068", team2Top: "#FFF5B4", team2Bottom: "#DCC878", serve: "#FF8C00"),
    ]

    public static let `default` = theme(withID: "midnightEmerald")

    public static func theme(withID id: String?) -> AppTheme {
        guard let id, let theme = all.first(where: { $0.id == id }) else {
            return all[0]
        }
        return theme
    }
}
