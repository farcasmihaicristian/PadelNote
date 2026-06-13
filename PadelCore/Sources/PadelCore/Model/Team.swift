public enum Team: String, Codable, Hashable, Sendable {
    case a
    case b

    public var opponent: Team {
        switch self {
        case .a: .b
        case .b: .a
        }
    }
}
