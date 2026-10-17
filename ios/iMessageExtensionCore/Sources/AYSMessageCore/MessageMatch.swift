import Foundation

public struct MessageMatch: Codable, Equatable, Sendable {
    public static let protocolVersion = 1
    public static let roundCount = 3

    public enum Stage: String, Codable, Sendable {
        case awaitingReply
        case roundResolved
        case matchResolved
    }

    public var version: Int
    public var matchID: UUID
    public var seed: UInt64
    public var roundIndex: Int
    public var stage: Stage
    public var rounds: [DuelRound]

    public init(seed: UInt64, matchID: UUID = UUID()) {
        version = Self.protocolVersion
        self.matchID = matchID
        self.seed = seed
        roundIndex = 0
        stage = .awaitingReply
        rounds = []
    }

    public var isValid: Bool {
        version == Self.protocolVersion &&
            (0..<Self.roundCount).contains(roundIndex) &&
            rounds.count <= Self.roundCount &&
            rounds.enumerated().allSatisfy { index, round in
                round.index == index && round.first.streak >= 0 &&
                    (round.second?.streak ?? 0) >= 0
            }
    }

    public var currentRound: DuelRound? {
        rounds.indices.contains(roundIndex) ? rounds[roundIndex] : nil
    }

    public var score: (first: Int, second: Int) {
        rounds.reduce(into: (first: 0, second: 0)) { score, round in
            guard let winner = round.winner else { return }
            if winner == .first { score.first += 1 }
            if winner == .second { score.second += 1 }
        }
    }

    /// Whether the device viewing a message is the match's first player.
    ///
    /// The first player opens every round, so an `awaitingReply` message is
    /// always sent by them and every resolved message by the second player.
    /// Messages participant identifiers differ per device, so the role is
    /// derived from who sent the bubble rather than stored in the state.
    public static func viewerIsFirst(stage: Stage, sentByViewer: Bool) -> Bool {
        (stage == .awaitingReply) == sentByViewer
    }

    /// The match score as (viewer, rival).
    public func score(viewerIsFirst: Bool) -> (mine: Int, theirs: Int) {
        let score = score
        return viewerIsFirst ? (score.first, score.second) : (score.second, score.first)
    }

    public mutating func recordFirst(_ result: DuelResult) {
        precondition(rounds.count == roundIndex)
        rounds.append(DuelRound(index: roundIndex, first: result))
        stage = .awaitingReply
    }

    public mutating func recordSecond(_ result: DuelResult) {
        precondition(stage == .awaitingReply && rounds.indices.contains(roundIndex))
        rounds[roundIndex].second = result
        stage = roundIndex == Self.roundCount - 1 ? .matchResolved : .roundResolved
    }

    public mutating func advanceRound(with result: DuelResult) {
        precondition(stage == .roundResolved && roundIndex + 1 < Self.roundCount)
        roundIndex += 1
        recordFirst(result)
    }
}

public struct DuelRound: Codable, Equatable, Sendable {
    public enum Winner: String, Codable, Sendable { case first, second, tie }

    public let index: Int
    public let first: DuelResult
    public var second: DuelResult?

    public init(index: Int, first: DuelResult, second: DuelResult? = nil) {
        self.index = index
        self.first = first
        self.second = second
    }

    public var winner: Winner? {
        guard let second else { return nil }
        if first.streak != second.streak {
            return first.streak > second.streak ? .first : .second
        }
        if abs(first.elapsedMilliseconds - second.elapsedMilliseconds) <= 40 {
            return .tie
        }
        return first.elapsedMilliseconds < second.elapsedMilliseconds ? .first : .second
    }

    /// True when both streaks match and only speed separated them.
    public var decidedByTime: Bool {
        guard let second, let winner, winner != .tie else { return false }
        return first.streak == second.streak
    }
}

public struct DuelResult: Codable, Equatable, Sendable {
    public let streak: Int
    public let elapsedMilliseconds: Int

    public init(streak: Int, elapsedMilliseconds: Int) {
        self.streak = max(0, streak)
        self.elapsedMilliseconds = max(0, elapsedMilliseconds)
    }
}

public enum MatchCodec {
    public enum CodecError: Error { case invalidURL, invalidPayload, invalidState }

    public static func encode(_ match: MessageMatch) throws -> URL {
        let data = try JSONEncoder().encode(match)
        let payload = data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        var components = URLComponents()
        components.scheme = "https"
        components.host = "areyoustupid.game"
        components.path = "/imessage"
        components.queryItems = [URLQueryItem(name: "state", value: payload)]
        guard let url = components.url, url.absoluteString.count < 5_000 else {
            throw CodecError.invalidURL
        }
        return url
    }

    public static func decode(_ url: URL) throws -> MessageMatch {
        guard let encoded = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "state" })?.value else {
            throw CodecError.invalidURL
        }
        var base64 = encoded.replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
        guard let data = Data(base64Encoded: base64),
              let match = try? JSONDecoder().decode(MessageMatch.self, from: data) else {
            throw CodecError.invalidPayload
        }
        guard match.isValid else { throw CodecError.invalidState }
        return match
    }
}
