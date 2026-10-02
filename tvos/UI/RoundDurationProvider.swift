//
//  RoundDurationProvider.swift
//  AYSHost
//
//  `RoomHost` needs a `ChallengeJudge` only to resolve a `{ challengeId,
//  seed, level }` tuple to a round duration (and reject an unknown id) —
//  content judging moved to the client entirely (`PartyChallengeRunner` on
//  the Flutter side, the same engine single-player uses), which resolved
//  docs/Gameplay/Multiplayer Challenges.md's "Phase 4 open question" by
//  making it moot; see the design-change note on `PlayerAction` in
//  `lib/multiplayer/protocol/protocol.dart` and docs/Meta/Decision Log.md.
//
//  The duration itself comes from `AYSChallengeCatalog`'s per-template
//  `maxDurationMs` (see ChallengeCatalog.swift for how each value was
//  derived from the matching Dart template) rather than one flat number for
//  every challenge — a stalled short challenge no longer leaves the host
//  waiting as long as a stalled long one. It's still a deliberate
//  over-approximation of each template's true worst case (see
//  ChallengeCatalog.swift), so a round is never unfairly short.
//

import AYSHostCore

struct RoundDurationProvider: ChallengeJudge {
    private static let byId: [String: ChallengeCatalogEntry] = Dictionary(
        uniqueKeysWithValues: AYSChallengeCatalog.all.map { ($0.id, $0) }
    )

    func spec(challengeId: String, seed: Int, level: Int) -> ChallengeSpec? {
        guard let entry = Self.byId[challengeId] else { return nil }
        return ChallengeSpec(
            challengeId: challengeId,
            seed: seed,
            level: level,
            durationMs: entry.maxDurationMs
        )
    }
}
