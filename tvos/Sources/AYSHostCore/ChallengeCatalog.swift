//
//  ChallengeCatalog.swift
//  AYSHostCore
//
//  Mirrors the id/minLevel/weight/starter metadata from
//  docs/Gameplay/Challenge Catalog.md (source of truth:
//  lib/challenges/registry.dart) — data only, not challenge logic. Picking
//  which challengeId to play next does NOT need to match Dart's algorithm
//  (unlike judging): the host is free to choose however it likes and simply
//  tells every phone what it picked via ROUND_START. See ChallengeJudge.swift
//  for the piece that *does* need cross-language agreement.
//

/// One template's pick metadata (no rendering/judging logic — that's
/// ChallengeJudge's job once Phase 4's open PRNG question is resolved).
public struct ChallengeCatalogEntry {
    public let id: String
    public let minLevel: Int
    public let weight: Double
    public let starter: Bool

    /// The longest this template's real Dart `duration` can ever be, across
    /// every level it can be picked at. Used only as the host's own
    /// round-timeout deadline (`ChallengeSpec.durationMs` — see
    /// RoundDurationProvider.swift): the client always judges against its
    /// own real, level-paced duration and reports a verdict well before
    /// this deadline in the normal case, so this value only matters for a
    /// seat that never answers at all (dropped connection). It intentionally
    /// mirrors each template's own `lib/challenges/*.dart` base duration
    /// rather than one blanket constant, so a stalled short challenge
    /// doesn't leave the host waiting as long as a stalled long one.
    ///
    /// Computed as ceil(baseMs / 0.49) for the common `p.pace(base, floor)`
    /// shape — 0.49 is `Difficulty.speedForLevel`'s slowest (most generous)
    /// speed, reached at level 1-2, and pace scales duration by `1/speed`, so
    /// this is every template's true ceiling *if* it could be picked at
    /// level 1 — a deliberate over-approximation for templates whose real
    /// `minLevel` implies a higher (shorter) floor, since simplicity here
    /// beats shaving a few hundred ms off an already-rare disconnect path.
    /// A few templates aren't a plain `pace(base)` and are hand-computed
    /// from their own formula instead (see the inline comments below);
    /// `too_fast` isn't paced at all in Dart, so its value is exact, not a
    /// ceiling. See docs/Meta/Decision Log.md.
    public let maxDurationMs: Int

    public init(id: String, minLevel: Int, weight: Double, starter: Bool = false, maxDurationMs: Int) {
        self.id = id
        self.minLevel = minLevel
        self.weight = weight
        self.starter = starter
        self.maxDurationMs = maxDurationMs
    }
}

public enum AYSChallengeCatalog {
    /// All 39 templates. Keep in sync with docs/Gameplay/Challenge
    /// Catalog.md in the same commit as any change there
    /// (docs/Meta/Documentation Rules.md).
    public static let all: [ChallengeCatalogEntry] = [
        // Colors
        .init(id: "tap_color", minLevel: 1, weight: 1.4, starter: true, maxDurationMs: 4490),
        .init(id: "dont_tap_color", minLevel: 2, weight: 1.0, starter: true, maxDurationMs: 4898),
        .init(id: "tap_actual_color", minLevel: 4, weight: 1.2, maxDurationMs: 4898),
        .init(id: "tap_color_moving", minLevel: 6, weight: 1.0, maxDurationMs: 5307),
        .init(id: "dont_tap_color_shifting", minLevel: 11, weight: 1.0, maxDurationMs: 6531),
        // Words
        .init(id: "tap_the_word", minLevel: 5, weight: 1.2, maxDurationMs: 5307),
        .init(id: "tap_word_button", minLevel: 5, weight: 1.0, maxDurationMs: 6123),
        .init(id: "odd_word_out", minLevel: 6, weight: 1.0, maxDurationMs: 5715),
        .init(id: "opposite", minLevel: 7, weight: 1.0, maxDurationMs: 5511),
        .init(id: "spell_count", minLevel: 9, weight: 0.9, maxDurationMs: 8572),
        .init(id: "tap_unwritten_color", minLevel: 15, weight: 0.8, maxDurationMs: 6939),
        // Counting
        .init(id: "tap_number", minLevel: 1, weight: 1.2, starter: true, maxDurationMs: 4490),
        .init(id: "tap_twice", minLevel: 2, weight: 1.0, starter: true, maxDurationMs: 5307),
        .init(id: "math", minLevel: 5, weight: 1.0, maxDurationMs: 7347),
        .init(id: "tap_exactly_n", minLevel: 6, weight: 1.0, maxDurationMs: 8164),
        .init(id: "count_shapes", minLevel: 7, weight: 1.0, maxDurationMs: 9388),
        .init(id: "spam_taps", minLevel: 8, weight: 1.0, maxDurationMs: 5307),
        // Patience
        .init(id: "dont_tap", minLevel: 4, weight: 1.2, maxDurationMs: 5919),
        .init(id: "do_nothing", minLevel: 6, weight: 1.0, maxDurationMs: 6123),
        .init(id: "hold_button", minLevel: 7, weight: 1.0, maxDurationMs: 5715),
        .init(id: "no_instruction", minLevel: 13, weight: 0.5, maxDurationMs: 4898),
        .init(id: "dont_follow", minLevel: 16, weight: 0.45, maxDurationMs: 5715),
        // Reaction
        // wait_for_green: duration = greenAt (900 + rng[0,1400)) + window
        // (max(420, 750/speed)) — greenAt's own randomness tops out at 2299,
        // not level-paced; window's ceiling at speed 0.49 is 1531.
        .init(id: "wait_for_green", minLevel: 5, weight: 1.0, maxDurationMs: 3830),
        // precise_timing: duration = targetTime (2 or 3s) + tolerance
        // (max(200, 460/speed), ceiling 939 at speed 0.49) + a fixed 260ms.
        .init(id: "precise_timing", minLevel: 9, weight: 0.9, maxDurationMs: 4199),
        // too_fast: Dart hardcodes `Duration(milliseconds: 2600)` with no
        // pace() call at all — this is the exact value, not a ceiling.
        .init(id: "too_fast", minLevel: 10, weight: 0.7, maxDurationMs: 2600),
        // Memory
        // remember_color: fixed showFor+blankFor (1320) + paced answerWindow
        // (ceiling 4898 at speed 0.49).
        .init(id: "remember_color", minLevel: 4, weight: 1.0, maxDurationMs: 6218),
        // remember_position: fixed showFor+blankFor (1250) + paced
        // answerWindow (ceiling 4898).
        .init(id: "remember_position", minLevel: 8, weight: 1.0, maxDurationMs: 6148),
        // remember_number: fixed showFor+blankFor (1400) + paced
        // answerWindow (ceiling 5307).
        .init(id: "remember_number", minLevel: 10, weight: 1.0, maxDurationMs: 6707),
        // last_color: sequence.length (capped at 5) * 420ms + paced
        // answerWindow (ceiling 4898).
        .init(id: "last_color", minLevel: 12, weight: 1.0, maxDurationMs: 6998),
        // Perception
        .init(id: "spot_different", minLevel: 5, weight: 1.0, maxDurationMs: 6531),
        .init(id: "size_compare", minLevel: 5, weight: 1.0, maxDurationMs: 4898),
        .init(id: "didnt_change", minLevel: 9, weight: 1.0, maxDurationMs: 6123),
        .init(id: "fake_buttons", minLevel: 11, weight: 1.0, maxDurationMs: 5307),
        // Tricks
        .init(id: "tap_nothing_button", minLevel: 8, weight: 1.0, maxDurationMs: 5307),
        .init(id: "left_right_swap", minLevel: 8, weight: 1.0, maxDurationMs: 5307),
        // tap_in_order: always 3 steps, paced 1100*3=3300ms base (ceiling
        // 6735 at speed 0.49).
        .init(id: "tap_in_order", minLevel: 9, weight: 1.0, maxDurationMs: 6735),
        .init(id: "ignore_next", minLevel: 12, weight: 0.8, maxDurationMs: 6123),
        .init(id: "rule_flip", minLevel: 14, weight: 1.0, maxDurationMs: 6531),
        // tap_reverse_order: up to 4 steps (level >= 20), paced
        // 1100*4=4400ms base (ceiling 8980 at speed 0.49).
        .init(id: "tap_reverse_order", minLevel: 17, weight: 0.8, maxDurationMs: 8980),
    ]
}
