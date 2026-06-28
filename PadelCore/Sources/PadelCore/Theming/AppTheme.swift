public struct AppTheme: Codable, Sendable, Hashable, Identifiable {
    public let id: String
    public let name: String
    public let team1Top: String
    public let team1Bottom: String
    public let team2Top: String
    public let team2Bottom: String
    public let serve: String

    public init(
        id: String,
        name: String,
        team1Top: String,
        team1Bottom: String,
        team2Top: String,
        team2Bottom: String,
        serve: String
    ) {
        self.id = id
        self.name = name
        self.team1Top = team1Top
        self.team1Bottom = team1Bottom
        self.team2Top = team2Top
        self.team2Bottom = team2Bottom
        self.serve = serve
    }
}
