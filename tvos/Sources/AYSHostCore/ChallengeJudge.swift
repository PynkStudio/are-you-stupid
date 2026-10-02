//
//  ChallengeJudge.swift
//  AYSHostCore
//
//  **Resolved, docs/Meta/Decision Log.md:** this used to be the seam for
//  "can this host correctly rebuild a Dart-generated challenge and judge a
//  tap against it" — docs/Gameplay/Multiplayer Challenges.md's "Phase 4
//  open question." It no longer needs to answer that at all: the *client*
//  now judges its own input (`PartyChallengeRunner`, the same engine
//  single-player uses) and reports the verdict in every `PLAYER_ACTION`
//  (`correct`/`reason`/`note`), which `RoomHost` trusts directly. See the
//  design-change note on `PlayerAction` in
//  `lib/multiplayer/protocol/protocol.dart`.
//
//  What's left here is much smaller: resolving `{ challengeId, seed, level }`
//  to a round *duration* (and rejecting an unknown `challengeId`) — `RoomHost`
//  still needs to know how long a round should run and still must not crash
//  on a bad tuple, neither of which requires rebuilding the challenge's
//  actual content.
//

/// The canonical shape a `{ challengeId, seed, level }` tuple resolves to —
/// just enough for `RoomHost` to run the round clock. Never carries
/// rendering or judging detail (targets, colors, layout, correct answer) —
/// that's entirely the client's job now.
public struct ChallengeSpec {
    public let challengeId: String
    public let seed: Int
    public let level: Int
    public let durationMs: Int

    public init(challengeId: String, seed: Int, level: Int, durationMs: Int) {
        self.challengeId = challengeId
        self.seed = seed
        self.level = level
        self.durationMs = durationMs
    }
}

/// The outcome of judging one player's input (or the lack of it). Built
/// directly from a trusted `PlayerAction`'s own `correct`/`reason`/`note`
/// fields for a real answer, or as a fixed fallback by `RoomHost` itself for
/// a seat that never answers at all — see `RoomHost.completeRound()`.
public struct JudgeVerdict {
    public let correct: Bool
    /// Shown to the player on a correct answer, if the challenge has one.
    public let note: String?
    /// Shown to the player on a wrong answer — the one-line explanation
    /// every template must ship per docs/Gameplay/Game Design Pillars.md.
    public let reason: String?

    public init(correct: Bool, note: String? = nil, reason: String? = nil) {
        self.correct = correct
        self.note = note
        self.reason = reason
    }
}

/// Resolves a `{ challengeId, seed, level }` tuple to its round duration.
/// `RoomHost` never talks to a template's actual content — only this.
public protocol ChallengeJudge {
    /// Resolves `{ challengeId, seed, level }` into a `ChallengeSpec`, or nil
    /// for an unknown `challengeId` — `RoomHost` treats that as a bad round
    /// (mirrors Dart's `templateById` returning null), never a crash.
    func spec(challengeId: String, seed: Int, level: Int) -> ChallengeSpec?
}
