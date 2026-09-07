//
//  ProtocolModel.swift
//  AYSProtocol
//
//  Swift mirror of lib/multiplayer/protocol/protocol.dart and
//  docs/Architecture/Multiplayer Protocol.md — the versioned JSONL wire
//  contract shared by the Dart client (Fastlane), the Dart headless host
//  reference (test/support), and this Swift host (tvOS + macOS board-only).
//
//  Semantics, field names, defaulting and forward-tolerance rules mirror the
//  Dart codec 1:1: unknown fields are ignored, an unknown `type` yields
//  .unknownType, anything that is not a single JSON object yields .malformed,
//  and the host gatekeeper is the only authority on `protocolVersion`.
//

import Foundation

/// Wire version. The host gatekeeper answers `REJECTED` on mismatch.
public let kProtocolVersion = 1

/// The wire name of a game mode (`START_GAME.mode`, `GAME_END.mode`, ...).
public enum GameMode: String, Equatable {
    case lastStupidStanding = "lss"
    case stupidBattle = "battle"

    /// Mirrors Dart's `fromWire`: unknown/missing mode falls back to battle.
    public static func fromWire(_ value: Any?) -> GameMode {
        guard let s = value as? String, let mode = GameMode(rawValue: s) else {
            return .stupidBattle
        }
        return mode
    }
}

/// Whether a round leaves the game in a terminal state (GAME_END).
public enum GameStatus: Equatable {
    case playing, ended
}

/// Decode outcome of a single JSONL line.
public enum DecodedMessage {
    /// A line that parsed into a known `PartyMessage`.
    case ok(any PartyMessage)
    /// A well-formed JSON object whose `type` is not recognized.
    case unknownType(String)
    /// Anything that is not a single JSON object (empty, garbage, truncated).
    case malformed(String)
}

// MARK: - Value read helpers (mirror Dart cast-with-fallback)

private func _str(_ w: [String: Any], _ key: String, _ fallback: String) -> String {
    w[key] as? String ?? fallback
}

private func _int(_ w: [String: Any], _ key: String, _ fallback: Int) -> Int {
    (w[key] as? NSNumber)?.intValue ?? fallback
}

private func _intOpt(_ w: [String: Any], _ key: String) -> Int? {
    (w[key] as? NSNumber)?.intValue
}

private func _bool(_ w: [String: Any], _ key: String, _ fallback: Bool) -> Bool {
    (w[key] as? NSNumber)?.boolValue ?? fallback
}

private func _dict(_ w: [String: Any], _ key: String) -> [String: Any] {
    w[key] as? [String: Any] ?? [:]
}

private func _list(_ w: [String: Any], _ key: String) -> [[String: Any]] {
    (w[key] as? [[String: Any]]) ?? []
}

/// Envelope: `{ protocolVersion, type, ts, ...body }` — same key order as
/// the Dart `PartyMessage.toWire()`.
public func envelope(_ type: String, _ ts: Int, _ body: [String: Any] = [:]) -> [String: Any] {
    var wire: [String: Any] = ["protocolVersion": kProtocolVersion, "type": type, "ts": ts]
    for (k, v) in body { wire[k] = v }
    return wire
}

// MARK: - Shared value types

/// A seat in the room (roster / ready snapshots).
public struct PlayerInfo: Equatable {
    public let playerId: String
    public let playerName: String
    public let emoji: String
    public let ready: Bool

    public init(playerId: String, playerName: String, emoji: String = "", ready: Bool = false) {
        self.playerId = playerId
        self.playerName = playerName
        self.emoji = emoji
        self.ready = ready
    }

    public func toWire() -> [String: Any] {
        ["playerId": playerId, "playerName": playerName, "emoji": emoji, "ready": ready]
    }

    public static func fromWire(_ w: [String: Any]) -> PlayerInfo {
        PlayerInfo(
            playerId: _str(w, "playerId", ""),
            playerName: _str(w, "playerName", ""),
            emoji: _str(w, "emoji", ""),
            ready: _bool(w, "ready", false)
        )
    }
}

/// One player's outcome inside `ROUND_RESULTS.results[]`.
public struct PlayerRoundResult: Equatable {
    public let playerId: String
    public let correct: Bool
    public let reason: String
    public let scoreDelta: Int
    public let reactionMs: Int?

    public init(playerId: String, correct: Bool, reason: String = "", scoreDelta: Int = 0, reactionMs: Int? = nil) {
        self.playerId = playerId
        self.correct = correct
        self.reason = reason
        self.scoreDelta = scoreDelta
        self.reactionMs = reactionMs
    }

    public func toWire() -> [String: Any] {
        var wire: [String: Any] = ["playerId": playerId, "correct": correct, "scoreDelta": scoreDelta]
        if !reason.isEmpty { wire["reason"] = reason }
        if let reactionMs { wire["reactionMs"] = reactionMs }
        return wire
    }

    public static func fromWire(_ w: [String: Any]) -> PlayerRoundResult {
        PlayerRoundResult(
            playerId: _str(w, "playerId", ""),
            correct: _bool(w, "correct", false),
            reason: _str(w, "reason", ""),
            scoreDelta: _int(w, "scoreDelta", 0),
            reactionMs: _intOpt(w, "reactionMs")
        )
    }
}

/// One player's final placing inside `GAME_END.results[]`.
public struct GameResultEntry: Equatable {
    public let playerId: String
    public let score: Int
    public let lives: Int?
    public let standing: Int

    public init(playerId: String, score: Int = 0, lives: Int? = nil, standing: Int) {
        self.playerId = playerId
        self.score = score
        self.lives = lives
        self.standing = standing
    }

    public func toWire() -> [String: Any] {
        var wire: [String: Any] = ["playerId": playerId, "score": score, "standing": standing]
        if let lives { wire["lives"] = lives }
        return wire
    }

    public static func fromWire(_ w: [String: Any]) -> GameResultEntry {
        GameResultEntry(
            playerId: _str(w, "playerId", ""),
            score: _int(w, "score", 0),
            lives: _intOpt(w, "lives"),
            standing: _int(w, "standing", 0)
        )
    }
}

/// The input a client submits in a `PLAYER_ACTION`.
///
/// Duplicate of the Dart `PartyAction`: `tap` (single pointer-down on a target
/// or the background) or `count` (the committed tap count for counting
/// families like `tap_twice` / `tap_exactly_n`, whose settle is judged by the
/// host against the count). The host rebuilds the canonical challenge and
/// judges input itself — it never trusts coordinates or timing from the client.
public struct PartyAction: Equatable {
    public let kind: String
    public let targetId: String?
    public let index: Int?
    public let count: Int?

    private init(kind: String, targetId: String?, index: Int?, count: Int?) {
        self.kind = kind
        self.targetId = targetId
        self.index = index
        self.count = count
    }

    public static func tap(targetId: String? = nil, index: Int? = nil) -> PartyAction {
        PartyAction(kind: "tap", targetId: targetId, index: index, count: nil)
    }

    public static func count(_ count: Int) -> PartyAction {
        PartyAction(kind: "count", targetId: nil, index: nil, count: count)
    }

    public func toWire() -> [String: Any] {
        if kind == "count" {
            return ["kind": kind, "count": count ?? 0]
        }
        var wire: [String: Any] = ["kind": kind]
        if let targetId { wire["targetId"] = targetId }
        if let index { wire["index"] = index }
        return wire
    }

    public static func fromWire(_ w: [String: Any]) -> PartyAction {
        let kind = _str(w, "kind", "tap")
        if kind == "count" {
            return .count(_int(w, "count", 0))
        }
        return .tap(targetId: w["targetId"] as? String, index: _intOpt(w, "index"))
    }
}

// MARK: - PartyMessage protocol

/// Base of every wire message. Each conformer knows its `type` string and how
/// to render its full JSON object (envelope included).
public protocol PartyMessage {
    /// Local monotonic ms where the message was sent.
    var ts: Int { get }
    var type: String { get }
    func toWire() -> [String: Any]
}

// MARK: - Lifecycle

/// client → host. First message after TCP connect.
public struct Hello: PartyMessage, Equatable {
    public let ts: Int
    public let appName: String
    public let appVersion: String
    public var type: String { "HELLO" }

    public init(appName: String, appVersion: String, ts: Int = 0) {
        self.appName = appName
        self.appVersion = appVersion
        self.ts = ts
    }

    public func toWire() -> [String: Any] {
        envelope(type, ts, ["appName": appName, "appVersion": appVersion])
    }

    public static func fromWire(_ w: [String: Any], ts: Int) -> Hello {
        Hello(appName: _str(w, "appName", ""), appVersion: _str(w, "appVersion", ""), ts: ts)
    }
}

/// host → client. Greets; on version mismatch send `Rejected` instead.
public struct HostHello: PartyMessage, Equatable {
    public let ts: Int
    public let hostName: String
    public let roomCode: String
    public let maxPlayers: Int
    public let protocolFeatures: [String]
    public var type: String { "HOST_HELLO" }

    public init(hostName: String, roomCode: String, maxPlayers: Int, protocolFeatures: [String] = [], ts: Int = 0) {
        self.hostName = hostName
        self.roomCode = roomCode
        self.maxPlayers = maxPlayers
        self.protocolFeatures = protocolFeatures
        self.ts = ts
    }

    public func toWire() -> [String: Any] {
        envelope(type, ts, [
            "hostName": hostName,
            "roomCode": roomCode,
            "maxPlayers": maxPlayers,
            "protocolFeatures": protocolFeatures,
        ])
    }

    public static func fromWire(_ w: [String: Any], ts: Int) -> HostHello {
        HostHello(
            hostName: _str(w, "hostName", ""),
            roomCode: _str(w, "roomCode", ""),
            maxPlayers: _int(w, "maxPlayers", 8),
            protocolFeatures: (w["protocolFeatures"] as? [String]) ?? [],
            ts: ts
        )
    }
}

/// either → either. Version or policy mismatch; the connection should close.
public struct Rejected: PartyMessage, Equatable {
    public let ts: Int
    public let reason: String
    public var type: String { "REJECTED" }

    public init(reason: String = "", ts: Int = 0) {
        self.reason = reason
        self.ts = ts
    }

    public func toWire() -> [String: Any] {
        envelope(type, ts, ["reason": reason])
    }

    public static func fromWire(_ w: [String: Any], ts: Int) -> Rejected {
        Rejected(reason: _str(w, "reason", ""), ts: ts)
    }
}

/// client → host. Request to join; host replies `PlayerJoined` or `PartyError`.
public struct JoinRoom: PartyMessage, Equatable {
    public let ts: Int
    public let playerName: String
    public let emoji: String
    public var type: String { "JOIN_ROOM" }

    public init(playerName: String, emoji: String = "", ts: Int = 0) {
        self.playerName = playerName
        self.emoji = emoji
        self.ts = ts
    }

    public func toWire() -> [String: Any] {
        envelope(type, ts, ["playerName": playerName, "emoji": emoji])
    }

    public static func fromWire(_ w: [String: Any], ts: Int) -> JoinRoom {
        JoinRoom(playerName: _str(w, "playerName", ""), emoji: _str(w, "emoji", ""), ts: ts)
    }
}

/// host → client. Full current player list snapshot, incl. self.
public struct PlayerJoined: PartyMessage, Equatable {
    public let ts: Int
    public let selfClientId: String
    public let roomId: String
    public let players: [PlayerInfo]
    public var type: String { "PLAYER_JOINED" }

    public init(selfClientId: String, roomId: String, players: [PlayerInfo], ts: Int = 0) {
        self.selfClientId = selfClientId
        self.roomId = roomId
        self.players = players
        self.ts = ts
    }

    public func toWire() -> [String: Any] {
        envelope(type, ts, [
            "selfClientId": selfClientId,
            "roomId": roomId,
            "players": players.map { $0.toWire() },
        ])
    }

    public static func fromWire(_ w: [String: Any], ts: Int) -> PlayerJoined {
        PlayerJoined(
            selfClientId: _str(w, "selfClientId", ""),
            roomId: _str(w, "roomId", ""),
            players: _list(w, "players").map(PlayerInfo.fromWire),
            ts: ts
        )
    }
}

/// client → host. Explicit leave; host then broadcasts `PlayerLeave`.
public struct LeaveRoom: PartyMessage, Equatable {
    public let ts: Int
    public var type: String { "LEAVE_ROOM" }

    public init(ts: Int = 0) { self.ts = ts }

    public func toWire() -> [String: Any] { envelope(type, ts) }

    public static func fromWire(_ w: [String: Any], ts: Int) -> LeaveRoom {
        LeaveRoom(ts: ts)
    }
}

/// host → clients. Removes a seat from the lobby/roster.
public struct PlayerLeave: PartyMessage, Equatable {
    public let ts: Int
    public let playerId: String
    public let reason: String
    public var type: String { "PLAYER_LEAVE" }

    public init(playerId: String, reason: String = "left", ts: Int = 0) {
        self.playerId = playerId
        self.reason = reason
        self.ts = ts
    }

    public func toWire() -> [String: Any] {
        envelope(type, ts, ["playerId": playerId, "reason": reason])
    }

    public static func fromWire(_ w: [String: Any], ts: Int) -> PlayerLeave {
        PlayerLeave(playerId: _str(w, "playerId", ""), reason: _str(w, "reason", "left"), ts: ts)
    }
}

/// client ↔ host. Toggle ready state.
public struct PlayerReady: PartyMessage, Equatable {
    public let ts: Int
    public let playerId: String
    public let ready: Bool
    public var type: String { "PLAYER_READY" }

    public init(playerId: String, ready: Bool, ts: Int = 0) {
        self.playerId = playerId
        self.ready = ready
        self.ts = ts
    }

    public func toWire() -> [String: Any] {
        envelope(type, ts, ["playerId": playerId, "ready": ready])
    }

    public static func fromWire(_ w: [String: Any], ts: Int) -> PlayerReady {
        PlayerReady(playerId: _str(w, "playerId", ""), ready: _bool(w, "ready", false), ts: ts)
    }
}

/// host → clients. Ready-state broadcast (lobby refresh).
public struct PlayerReadyRoster: PartyMessage, Equatable {
    public let ts: Int
    public let players: [PlayerInfo]
    public var type: String { "PLAYER_READY_ROSTER" }

    public init(players: [PlayerInfo], ts: Int = 0) {
        self.players = players
        self.ts = ts
    }

    public func toWire() -> [String: Any] {
        envelope(type, ts, ["players": players.map { $0.toWire() }])
    }

    public static func fromWire(_ w: [String: Any], ts: Int) -> PlayerReadyRoster {
        PlayerReadyRoster(players: _list(w, "players").map(PlayerInfo.fromWire), ts: ts)
    }
}

/// host → clients. Only sent when ≥2 ready.
/// (`config` is an opaque JSON object, so this is message is not Equatable.)
public struct StartGame: PartyMessage {
    public let ts: Int
    public let mode: GameMode
    public let config: [String: Any]
    public var type: String { "START_GAME" }

    public init(mode: GameMode, config: [String: Any] = [:], ts: Int = 0) {
        self.mode = mode
        self.config = config
        self.ts = ts
    }

    public func toWire() -> [String: Any] {
        envelope(type, ts, ["mode": mode.rawValue, "config": config])
    }

    public static func fromWire(_ w: [String: Any], ts: Int) -> StartGame {
        StartGame(mode: GameMode.fromWire(w["mode"]), config: _dict(w, "config"), ts: ts)
    }
}

/// host → clients. In-match disconnect; grace window applies.
public struct PlayerDisconnected: PartyMessage, Equatable {
    public let ts: Int
    public let playerId: String
    public var type: String { "PLAYER_DISCONNECTED" }

    public init(playerId: String, ts: Int = 0) {
        self.playerId = playerId
        self.ts = ts
    }

    public func toWire() -> [String: Any] {
        envelope(type, ts, ["playerId": playerId])
    }

    public static func fromWire(_ w: [String: Any], ts: Int) -> PlayerDisconnected {
        PlayerDisconnected(playerId: _str(w, "playerId", ""), ts: ts)
    }
}

/// host → clients. Grace-window reconnect restored state.
public struct PlayerReconnected: PartyMessage, Equatable {
    public let ts: Int
    public let playerId: String
    public var type: String { "PLAYER_RECONNECTED" }

    public init(playerId: String, ts: Int = 0) {
        self.playerId = playerId
        self.ts = ts
    }

    public func toWire() -> [String: Any] {
        envelope(type, ts, ["playerId": playerId])
    }

    public static func fromWire(_ w: [String: Any], ts: Int) -> PlayerReconnected {
        PlayerReconnected(playerId: _str(w, "playerId", ""), ts: ts)
    }
}

/// host → clients. Final; clients render result + share.
public struct GameEnd: PartyMessage, Equatable {
    public let ts: Int
    public let mode: GameMode
    public let results: [GameResultEntry]
    public let winnerId: String?
    public var type: String { "GAME_END" }

    public init(mode: GameMode, results: [GameResultEntry], winnerId: String?, ts: Int = 0) {
        self.mode = mode
        self.results = results
        self.winnerId = winnerId
        self.ts = ts
    }

    public func toWire() -> [String: Any] {
        var wire: [String: Any] = ["mode": mode.rawValue, "results": results.map { $0.toWire() }]
        if let winnerId { wire["winnerId"] = winnerId }
        return envelope(type, ts, wire)
    }

    public static func fromWire(_ w: [String: Any], ts: Int) -> GameEnd {
        GameEnd(
            mode: GameMode.fromWire(w["mode"]),
            results: _list(w, "results").map(GameResultEntry.fromWire),
            winnerId: w["winnerId"] as? String,
            ts: ts
        )
    }
}

// MARK: - Rounds

/// host → clients. The SAME challenge for every player, from one seed.
public struct RoundStart: PartyMessage {
    public let ts: Int
    public let roundId: String
    public let challengeId: String
    public let seed: Int
    /// Shared epoch chosen by the host; clients count down from it.
    public let startAt: Int
    public let durationMs: Int
/// Round-scoped config, e.g. `{ "level": 12 }`. Must stay small.
/// (`config` is an opaque JSON object, so this message is not Equatable.)
public let config: [String: Any]
public var type: String { "ROUND_START" }

    public init(roundId: String, challengeId: String, seed: Int, startAt: Int, durationMs: Int, config: [String: Any] = [:], ts: Int = 0) {
        self.roundId = roundId
        self.challengeId = challengeId
        self.seed = seed
        self.startAt = startAt
        self.durationMs = durationMs
        self.config = config
        self.ts = ts
    }

    public func toWire() -> [String: Any] {
        envelope(type, ts, [
            "roundId": roundId,
            "challengeId": challengeId,
            "seed": seed,
            "startAt": startAt,
            "durationMs": durationMs,
            "config": config,
        ])
    }

    public static func fromWire(_ w: [String: Any], ts: Int) -> RoundStart {
        RoundStart(
            roundId: _str(w, "roundId", ""),
            challengeId: _str(w, "challengeId", ""),
            seed: _int(w, "seed", 0),
            startAt: _int(w, "startAt", 0),
            durationMs: _int(w, "durationMs", 0),
            config: _dict(w, "config"),
            ts: ts
        )
    }
}

/// host → clients. Countdown sync (`READY` / `GO`); `atMs` = host monotonic.
public struct RoundCountdown: PartyMessage, Equatable {
    public let ts: Int
    public let roundId: String
    public let atMs: Int
    public let state: String
    public var type: String { "ROUND_COUNTDOWN" }

    public init(roundId: String, atMs: Int, state: String, ts: Int = 0) {
        self.roundId = roundId
        self.atMs = atMs
        self.state = state
        self.ts = ts
    }

    public func toWire() -> [String: Any] {
        envelope(type, ts, ["roundId": roundId, "atMs": atMs, "state": state])
    }

    public static func fromWire(_ w: [String: Any], ts: Int) -> RoundCountdown {
        RoundCountdown(roundId: _str(w, "roundId", ""), atMs: _int(w, "atMs", 0), state: _str(w, "state", "READY"), ts: ts)
    }
}

/// client → host. Input only; host judges.
public struct PlayerAction: PartyMessage, Equatable {
    public let ts: Int
    public let playerId: String
    public let roundId: String
    public let action: PartyAction
    /// Used only for the reaction-time bonus/tie-break. Never authoritative.
    public let clientTimestampMs: Int
    public var type: String { "PLAYER_ACTION" }

    public init(playerId: String, roundId: String, action: PartyAction, clientTimestampMs: Int = 0, ts: Int = 0) {
        self.playerId = playerId
        self.roundId = roundId
        self.action = action
        self.clientTimestampMs = clientTimestampMs
        self.ts = ts
    }

    public func toWire() -> [String: Any] {
        envelope(type, ts, [
            "playerId": playerId,
            "roundId": roundId,
            "action": action.toWire(),
            "clientTimestampMs": clientTimestampMs,
        ])
    }

    public static func fromWire(_ w: [String: Any], ts: Int) -> PlayerAction {
        PlayerAction(
            playerId: _str(w, "playerId", ""),
            roundId: _str(w, "roundId", ""),
            action: PartyAction.fromWire(_dict(w, "action")),
            clientTimestampMs: _int(w, "clientTimestampMs", 0),
            ts: ts
        )
    }
}

/// host → each client. Per-player private result; also drives lives.
public struct RoundResult: PartyMessage, Equatable {
    public let ts: Int
    public let roundId: String
    public let correct: Bool
    public let reason: String
    public let scoreDelta: Int
    public let actionReceivedMs: Int?
    public var type: String { "ROUND_RESULT" }

    public init(roundId: String, correct: Bool, reason: String = "", scoreDelta: Int = 0, actionReceivedMs: Int? = nil, ts: Int = 0) {
        self.roundId = roundId
        self.correct = correct
        self.reason = reason
        self.scoreDelta = scoreDelta
        self.actionReceivedMs = actionReceivedMs
        self.ts = ts
    }

    public func toWire() -> [String: Any] {
        var wire: [String: Any] = ["roundId": roundId, "correct": correct, "scoreDelta": scoreDelta]
        if !reason.isEmpty { wire["reason"] = reason }
        if let actionReceivedMs { wire["actionReceivedMs"] = actionReceivedMs }
        return envelope(type, ts, wire)
    }

    public static func fromWire(_ w: [String: Any], ts: Int) -> RoundResult {
        RoundResult(
            roundId: _str(w, "roundId", ""),
            correct: _bool(w, "correct", false),
            reason: _str(w, "reason", ""),
            scoreDelta: _int(w, "scoreDelta", 0),
            actionReceivedMs: _intOpt(w, "actionReceivedMs"),
            ts: ts
        )
    }
}

/// host → clients. Aggregated reveal for the board + cross-phone standings.
public struct RoundResults: PartyMessage, Equatable {
    public let ts: Int
    public let roundId: String
    public let results: [PlayerRoundResult]
    public var type: String { "ROUND_RESULTS" }

    public init(roundId: String, results: [PlayerRoundResult], ts: Int = 0) {
        self.roundId = roundId
        self.results = results
        self.ts = ts
    }

    public func toWire() -> [String: Any] {
        envelope(type, ts, ["roundId": roundId, "results": results.map { $0.toWire() }])
    }

    public static func fromWire(_ w: [String: Any], ts: Int) -> RoundResults {
        RoundResults(roundId: _str(w, "roundId", ""), results: _list(w, "results").map(PlayerRoundResult.fromWire), ts: ts)
    }
}

/// host → clients. Bookend; clients lock accuracy/points, board shows NEXT ROUND.
public struct RoundEnd: PartyMessage, Equatable {
    public let ts: Int
    public let roundId: String
    public var type: String { "ROUND_END" }

    public init(roundId: String, ts: Int = 0) {
        self.roundId = roundId
        self.ts = ts
    }

    public func toWire() -> [String: Any] {
        envelope(type, ts, ["roundId": roundId])
    }

    public static func fromWire(_ w: [String: Any], ts: Int) -> RoundEnd {
        RoundEnd(roundId: _str(w, "roundId", ""), ts: ts)
    }
}

/// host → clients. Broadcast on reaching 0 lives.
public struct PlayerEliminated: PartyMessage, Equatable {
    public let ts: Int
    public let roundId: String
    public let playerId: String
    public let livesLeft: Int
    public var type: String { "PLAYER_ELIMINATED" }

    public init(roundId: String, playerId: String, livesLeft: Int = 0, ts: Int = 0) {
        self.roundId = roundId
        self.playerId = playerId
        self.livesLeft = livesLeft
        self.ts = ts
    }

    public func toWire() -> [String: Any] {
        envelope(type, ts, ["roundId": roundId, "playerId": playerId, "livesLeft": livesLeft])
    }

    public static func fromWire(_ w: [String: Any], ts: Int) -> PlayerEliminated {
        PlayerEliminated(roundId: _str(w, "roundId", ""), playerId: _str(w, "playerId", ""), livesLeft: _int(w, "livesLeft", 0), ts: ts)
    }
}

/// host → clients. Live scoreboard patch.
public struct PlayerScore: PartyMessage, Equatable {
    public let ts: Int
    public let playerId: String
    public let mode: GameMode
    public let score: Int
    /// Lives remaining (elimination modes). Null in pure point modes.
    public let lives: Int?
    public let standing: Int
    public var type: String { "PLAYER_SCORE" }

    public init(playerId: String, mode: GameMode, score: Int, lives: Int? = nil, standing: Int = 0, ts: Int = 0) {
        self.playerId = playerId
        self.mode = mode
        self.score = score
        self.lives = lives
        self.standing = standing
        self.ts = ts
    }

    public func toWire() -> [String: Any] {
        var wire: [String: Any] = ["playerId": playerId, "mode": mode.rawValue, "score": score, "standing": standing]
        if let lives { wire["lives"] = lives }
        return envelope(type, ts, wire)
    }

    public static func fromWire(_ w: [String: Any], ts: Int) -> PlayerScore {
        PlayerScore(
            playerId: _str(w, "playerId", ""),
            mode: GameMode.fromWire(w["mode"]),
            score: _int(w, "score", 0),
            lives: _intOpt(w, "lives"),
            standing: _int(w, "standing", 0),
            ts: ts
        )
    }
}

// MARK: - Errors

/// either → either. `code` is one of `ROOM_FULL`, `ROUND_CLOSED`,
/// `DUPLICATE_ACTION`, `BAD_MESSAGE`, ...; `detail` is the readable why.
public struct PartyError: PartyMessage, Equatable {
    public let ts: Int
    public let code: String
    public let detail: String
    public var type: String { "ERROR" }

    public init(code: String, detail: String = "", ts: Int = 0) {
        self.code = code
        self.detail = detail
        self.ts = ts
    }

    public func toWire() -> [String: Any] {
        envelope(type, ts, ["code": code, "detail": detail])
    }

    public static func fromWire(_ w: [String: Any], ts: Int) -> PartyError {
        PartyError(code: _str(w, "code", ""), detail: _str(w, "detail", ""), ts: ts)
    }
}

// MARK: - Codec

/// The JSONL codec shared by host, client, mirrors and tests.
public enum PartyProtocol {
    /// Serializes a message to one JSONL line (no trailing newline).
    public static func encode(_ message: any PartyMessage) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: message.toWire(), options: [])
        guard let line = String(data: data, encoding: .utf8) else {
            throw PartyProtocolError.encode
        }
        return line
    }

    /// Parses one line. See `DecodedMessage` for outcome semantics.
    public static func decode(_ line: String) -> DecodedMessage {
        guard let data = line.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data),
              let wire = json as? [String: Any] else {
            return .malformed("not JSON / not an object")
        }
        guard let type = wire["type"] as? String, !type.isEmpty else {
            return .malformed("missing type")
        }
        let ts = _int(wire, "ts", 0)

        switch type {
        case "HELLO": return .ok(Hello.fromWire(wire, ts: ts))
        case "HOST_HELLO": return .ok(HostHello.fromWire(wire, ts: ts))
        case "REJECTED": return .ok(Rejected.fromWire(wire, ts: ts))
        case "JOIN_ROOM": return .ok(JoinRoom.fromWire(wire, ts: ts))
        case "PLAYER_JOINED": return .ok(PlayerJoined.fromWire(wire, ts: ts))
        case "LEAVE_ROOM": return .ok(LeaveRoom.fromWire(wire, ts: ts))
        case "PLAYER_LEAVE": return .ok(PlayerLeave.fromWire(wire, ts: ts))
        case "PLAYER_READY": return .ok(PlayerReady.fromWire(wire, ts: ts))
        case "PLAYER_READY_ROSTER": return .ok(PlayerReadyRoster.fromWire(wire, ts: ts))
        case "START_GAME": return .ok(StartGame.fromWire(wire, ts: ts))
        case "PLAYER_DISCONNECTED": return .ok(PlayerDisconnected.fromWire(wire, ts: ts))
        case "PLAYER_RECONNECTED": return .ok(PlayerReconnected.fromWire(wire, ts: ts))
        case "GAME_END": return .ok(GameEnd.fromWire(wire, ts: ts))
        case "ROUND_START": return .ok(RoundStart.fromWire(wire, ts: ts))
        case "ROUND_COUNTDOWN": return .ok(RoundCountdown.fromWire(wire, ts: ts))
        case "PLAYER_ACTION": return .ok(PlayerAction.fromWire(wire, ts: ts))
        case "ROUND_RESULT": return .ok(RoundResult.fromWire(wire, ts: ts))
        case "ROUND_RESULTS": return .ok(RoundResults.fromWire(wire, ts: ts))
        case "ROUND_END": return .ok(RoundEnd.fromWire(wire, ts: ts))
        case "PLAYER_ELIMINATED": return .ok(PlayerEliminated.fromWire(wire, ts: ts))
        case "PLAYER_SCORE": return .ok(PlayerScore.fromWire(wire, ts: ts))
        case "ERROR": return .ok(PartyError.fromWire(wire, ts: ts))
        default: return .unknownType(type)
        }
    }

    /// Convenience: encodes then decodes (round-trip helper for tests).
    public static func roundTrip(_ message: any PartyMessage) throws -> DecodedMessage {
        decode(try encode(message))
    }
}

public enum PartyProtocolError: Error {
    case encode
}