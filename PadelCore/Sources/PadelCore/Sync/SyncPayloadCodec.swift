import Foundation

public enum SyncPayloadCodec {
    public enum Kind: String, Codable {
        case liveScore
        case completedMatch
        case pointLog
        case defaultRules
    }

    public static let kindKey = "kind"
    public static let payloadKey = "payload"

    private static let matchIDKey = "matchID"
    private static let gameScoreKey = "gameScore"
    private static let setGamesKey = "setGames"
    private static let completedSetScoresKey = "completedSetScores"
    private static let isMatchOverKey = "isMatchOver"
    private static let isSessionActiveKey = "isSessionActive"
    private static let teamANameKey = "teamAName"
    private static let teamBNameKey = "teamBName"
    private static let playerA1NameKey = "playerA1Name"
    private static let playerA2NameKey = "playerA2Name"
    private static let playerB1NameKey = "playerB1Name"
    private static let playerB2NameKey = "playerB2Name"
    private static let pointCountKey = "pointCount"
    private static let updatedAtKey = "updatedAt"

    public static func encodeLiveScore(_ snapshot: LiveScoreSnapshot) -> [String: Any] {
        var dictionary: [String: Any] = [
            kindKey: Kind.liveScore.rawValue,
            matchIDKey: snapshot.matchID.uuidString,
            gameScoreKey: snapshot.gameScore,
            setGamesKey: snapshot.setGames,
            completedSetScoresKey: snapshot.completedSetScores,
            isMatchOverKey: snapshot.isMatchOver,
            isSessionActiveKey: snapshot.isSessionActive,
            pointCountKey: snapshot.pointCount,
            updatedAtKey: snapshot.updatedAt.timeIntervalSince1970
        ]

        if let teamAName = snapshot.teamAName {
            dictionary[teamANameKey] = teamAName
        }
        if let teamBName = snapshot.teamBName {
            dictionary[teamBNameKey] = teamBName
        }
        if let playerA1Name = snapshot.playerA1Name {
            dictionary[playerA1NameKey] = playerA1Name
        }
        if let playerA2Name = snapshot.playerA2Name {
            dictionary[playerA2NameKey] = playerA2Name
        }
        if let playerB1Name = snapshot.playerB1Name {
            dictionary[playerB1NameKey] = playerB1Name
        }
        if let playerB2Name = snapshot.playerB2Name {
            dictionary[playerB2NameKey] = playerB2Name
        }

        return dictionary
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

    public static func encodeDefaultRules(_ rules: MatchRules) -> [String: Any] {
        [
            kindKey: Kind.defaultRules.rawValue,
            payloadKey: (try? JSONEncoder().encode(rules)) as Any
        ]
    }

    public static func decodeDefaultRules(from dictionary: [String: Any]) -> MatchRules? {
        guard
            dictionary[kindKey] as? String == Kind.defaultRules.rawValue,
            let data = payloadData(from: dictionary)
        else { return nil }
        return try? JSONDecoder().decode(MatchRules.self, from: data)
    }

    public static func decodeLiveScore(from dictionary: [String: Any]) -> LiveScoreSnapshot? {
        guard dictionary[kindKey] as? String == Kind.liveScore.rawValue else { return nil }

        if let data = payloadData(from: dictionary),
           let snapshot = try? JSONDecoder().decode(LiveScoreSnapshot.self, from: data) {
            return snapshot
        }

        guard
            let matchIDString = dictionary[matchIDKey] as? String,
            let matchID = UUID(uuidString: matchIDString),
            let gameScore = dictionary[gameScoreKey] as? String,
            let setGames = dictionary[setGamesKey] as? String,
            let completedSetScores = dictionary[completedSetScoresKey] as? [String],
            let pointCount = dictionary[pointCountKey] as? Int
        else { return nil }

        let isMatchOver = (dictionary[isMatchOverKey] as? Bool) ?? false
        let isSessionActive = (dictionary[isSessionActiveKey] as? Bool) ?? false
        let updatedAt: Date = {
            if let interval = dictionary[updatedAtKey] as? TimeInterval {
                return Date(timeIntervalSince1970: interval)
            }
            if let interval = dictionary[updatedAtKey] as? Double {
                return Date(timeIntervalSince1970: interval)
            }
            return .now
        }()

        return LiveScoreSnapshot(
            matchID: matchID,
            gameScore: gameScore,
            setGames: setGames,
            completedSetScores: completedSetScores,
            isMatchOver: isMatchOver,
            playerNames: MatchPlayerNames(
                playerA1Name: dictionary[playerA1NameKey] as? String,
                playerA2Name: dictionary[playerA2NameKey] as? String,
                playerB1Name: dictionary[playerB1NameKey] as? String,
                playerB2Name: dictionary[playerB2NameKey] as? String,
                teamAName: dictionary[teamANameKey] as? String,
                teamBName: dictionary[teamBNameKey] as? String
            ),
            pointCount: pointCount,
            updatedAt: updatedAt,
            isSessionActive: isSessionActive
        )
    }

    public static func decodeCompletedMatch(from dictionary: [String: Any]) -> MatchTransferPayload? {
        guard
            dictionary[kindKey] as? String == Kind.completedMatch.rawValue,
            let data = payloadData(from: dictionary)
        else { return nil }
        return try? JSONDecoder().decode(MatchTransferPayload.self, from: data)
    }

    public static func decodePointLog(from dictionary: [String: Any]) -> MatchTransferPayload? {
        guard
            dictionary[kindKey] as? String == Kind.pointLog.rawValue,
            let data = payloadData(from: dictionary)
        else { return nil }
        return try? JSONDecoder().decode(MatchTransferPayload.self, from: data)
    }

    public static func hasSyncPayload(_ dictionary: [String: Any]) -> Bool {
        guard let kind = dictionary[kindKey] as? String else { return false }
        switch kind {
        case Kind.liveScore.rawValue:
            return dictionary[matchIDKey] != nil || payloadData(from: dictionary) != nil
        case Kind.completedMatch.rawValue, Kind.pointLog.rawValue, Kind.defaultRules.rawValue:
            return payloadData(from: dictionary) != nil
        default:
            return false
        }
    }

    private static func payloadData(from dictionary: [String: Any]) -> Data? {
        if let data = dictionary[payloadKey] as? Data {
            return data
        }
        if let data = dictionary[payloadKey] as? NSData {
            return data as Data
        }
        return nil
    }
}
