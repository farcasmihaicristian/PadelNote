import Foundation

public enum SyncPayloadCodec {
    public enum Kind: String, Codable {
        case liveScore
        case completedMatch
        case pointLog
    }

    public static let kindKey = "kind"
    public static let payloadKey = "payload"

    public static func encodeLiveScore(_ snapshot: LiveScoreSnapshot) -> [String: Any] {
        [
            kindKey: Kind.liveScore.rawValue,
            payloadKey: (try? JSONEncoder().encode(snapshot)) as Any
        ]
    }

    public static func encodeCompletedMatch(_ payload: MatchTransferPayload) -> [String: Any] {
        [
            kindKey: Kind.completedMatch.rawValue,
            payloadKey: (try? JSONEncoder().encode(payload)) as Any
        ]
    }

    public static func encodePointLog(_ payload: MatchTransferPayload) -> [String: Any] {
        [
            kindKey: Kind.pointLog.rawValue,
            payloadKey: (try? JSONEncoder().encode(payload)) as Any
        ]
    }

    public static func decodeLiveScore(from dictionary: [String: Any]) -> LiveScoreSnapshot? {
        guard
            dictionary[kindKey] as? String == Kind.liveScore.rawValue,
            let data = dictionary[payloadKey] as? Data
        else { return nil }
        return try? JSONDecoder().decode(LiveScoreSnapshot.self, from: data)
    }

    public static func decodeCompletedMatch(from dictionary: [String: Any]) -> MatchTransferPayload? {
        guard
            let kind = dictionary[kindKey] as? String,
            kind == Kind.completedMatch.rawValue || kind == Kind.pointLog.rawValue,
            let data = dictionary[payloadKey] as? Data
        else { return nil }
        return try? JSONDecoder().decode(MatchTransferPayload.self, from: data)
    }
}
