import 'dart:math';

import '../core/challenge.dart';
import '../core/difficulty.dart';
import '../i18n/app_locale.dart';
import 'color_challenges.dart';
import 'counting_challenges.dart';
import 'memory_challenges.dart';
import 'patience_challenges.dart';
import 'perception_challenges.dart';
import 'trick_challenges.dart';
import 'word_challenges.dart';

/// THE list of challenge templates.
///
/// To add a challenge: write the class/builder in `lib/challenges/`, then add
/// one entry here. Nothing else changes. Keep `minLevel` honest — mean traps
/// must never show up in the first levels or the joke stops being funny.
const kChallengeTemplates = <ChallengeTemplate>[
  // ---------------------------------------------------------------- starters
  ChallengeTemplate(
    id: 'tap_color',
    tag: ChallengeTag.color,
    build: buildTapColor,
    starter: true,
    weight: 1.4,
  ),
  ChallengeTemplate(
    id: 'tap_number',
    tag: ChallengeTag.counting,
    build: buildTapNumber,
    starter: true,
    weight: 1.2,
  ),
  ChallengeTemplate(
    id: 'tap_twice',
    tag: ChallengeTag.counting,
    build: ExactTapsChallenge.twice,
    minLevel: 2,
    starter: true,
  ),
  ChallengeTemplate(
    id: 'dont_tap_color',
    tag: ChallengeTag.color,
    build: buildDontTapColor,
    minLevel: 2,
    starter: true,
  ),

  // ------------------------------------------------------------------- color
  ChallengeTemplate(
    id: 'tap_actual_color',
    tag: ChallengeTag.color,
    build: buildTapActualColor,
    minLevel: 4,
    weight: 1.2,
  ),
  ChallengeTemplate(
    id: 'tap_the_word',
    tag: ChallengeTag.word,
    build: buildTapTheWord,
    minLevel: 5,
    weight: 1.2,
  ),
  ChallengeTemplate(
    id: 'tap_color_moving',
    tag: ChallengeTag.color,
    build: MovingColorChallenge.build,
    minLevel: 6,
  ),
  ChallengeTemplate(
    id: 'dont_tap_color_shifting',
    tag: ChallengeTag.color,
    build: ShiftingColorsChallenge.new,
    minLevel: 11,
  ),
  ChallengeTemplate(
    id: 'tap_unwritten_color',
    tag: ChallengeTag.word,
    build: buildUnwrittenColor,
    minLevel: 15,
    weight: 0.8,
  ),

  // -------------------------------------------------------------------- word
  ChallengeTemplate(
    id: 'tap_word_button',
    tag: ChallengeTag.word,
    build: buildTapWordButton,
    minLevel: 5,
  ),
  ChallengeTemplate(
    id: 'tap_nothing_button',
    tag: ChallengeTag.trick,
    build: buildTapNothingButton,
    minLevel: 8,
  ),
  ChallengeTemplate(
    id: 'odd_word_out',
    tag: ChallengeTag.word,
    build: buildOddWordOut,
    minLevel: 6,
  ),
  ChallengeTemplate(
    id: 'opposite',
    tag: ChallengeTag.word,
    build: buildOpposite,
    minLevel: 7,
  ),
  ChallengeTemplate(
    id: 'spell_count',
    tag: ChallengeTag.word,
    build: buildSpellCount,
    minLevel: 9,
    weight: 0.9,
  ),

  // ---------------------------------------------------------------- counting
  ChallengeTemplate(
    id: 'tap_exactly_n',
    tag: ChallengeTag.counting,
    build: ExactTapsChallenge.exactly,
    minLevel: 6,
  ),
  ChallengeTemplate(
    id: 'math',
    tag: ChallengeTag.counting,
    build: buildMath,
    minLevel: 5,
  ),
  ChallengeTemplate(
    id: 'count_shapes',
    tag: ChallengeTag.counting,
    build: buildCountShapes,
    minLevel: 7,
  ),
  ChallengeTemplate(
    id: 'spam_taps',
    tag: ChallengeTag.reaction,
    build: SpamTapsChallenge.build,
    minLevel: 8,
  ),

  // --------------------------------------------------------------- patience
  ChallengeTemplate(
    id: 'dont_tap',
    tag: ChallengeTag.patience,
    build: DontTapChallenge.new,
    minLevel: 4,
    weight: 1.2,
  ),
  ChallengeTemplate(
    id: 'do_nothing',
    tag: ChallengeTag.patience,
    build: DoNothingChallenge.new,
    minLevel: 6,
  ),
  ChallengeTemplate(
    id: 'wait_for_green',
    tag: ChallengeTag.reaction,
    build: WaitForGreenChallenge.build,
    minLevel: 5,
  ),
  ChallengeTemplate(
    id: 'precise_timing',
    tag: ChallengeTag.reaction,
    build: PreciseTimingChallenge.build,
    minLevel: 9,
    weight: 0.9,
  ),
  ChallengeTemplate(
    id: 'hold_button',
    tag: ChallengeTag.patience,
    build: HoldButtonChallenge.new,
    minLevel: 7,
  ),
  ChallengeTemplate(
    id: 'no_instruction',
    tag: ChallengeTag.trick,
    build: NoInstructionChallenge.new,
    minLevel: 13,
    weight: 0.5,
  ),
  ChallengeTemplate(
    id: 'dont_follow',
    tag: ChallengeTag.trick,
    build: DontFollowChallenge.new,
    minLevel: 16,
    weight: 0.45,
  ),

  // ----------------------------------------------------------------- memory
  ChallengeTemplate(
    id: 'remember_color',
    tag: ChallengeTag.memory,
    build: RememberColorChallenge.new,
    minLevel: 4,
  ),
  ChallengeTemplate(
    id: 'remember_position',
    tag: ChallengeTag.memory,
    build: RememberPositionChallenge.new,
    minLevel: 8,
  ),
  ChallengeTemplate(
    id: 'remember_number',
    tag: ChallengeTag.memory,
    build: RememberNumberChallenge.new,
    minLevel: 10,
  ),
  ChallengeTemplate(
    id: 'last_color',
    tag: ChallengeTag.memory,
    build: LastColorChallenge.build,
    minLevel: 12,
  ),

  // ------------------------------------------------------------- perception
  ChallengeTemplate(
    id: 'spot_different',
    tag: ChallengeTag.perception,
    build: buildSpotDifferent,
    minLevel: 5,
  ),
  ChallengeTemplate(
    id: 'size_compare',
    tag: ChallengeTag.perception,
    build: buildSizeCompare,
    minLevel: 5,
  ),
  ChallengeTemplate(
    id: 'didnt_change',
    tag: ChallengeTag.perception,
    build: DidntChangeChallenge.new,
    minLevel: 9,
  ),
  ChallengeTemplate(
    id: 'fake_buttons',
    tag: ChallengeTag.perception,
    build: buildFakeButtons,
    minLevel: 11,
  ),

  // ----------------------------------------------------------------- tricks
  ChallengeTemplate(
    id: 'left_right_swap',
    tag: ChallengeTag.trick,
    build: LeftRightSwapChallenge.new,
    minLevel: 8,
  ),
  ChallengeTemplate(
    id: 'tap_in_order',
    tag: ChallengeTag.trick,
    build: OrderChallenge.ascendingBuild,
    minLevel: 9,
  ),
  ChallengeTemplate(
    id: 'too_fast',
    tag: ChallengeTag.trick,
    build: TooFastChallenge.new,
    minLevel: 10,
    weight: 0.7,
  ),
  ChallengeTemplate(
    id: 'ignore_next',
    tag: ChallengeTag.trick,
    build: buildIgnoreNext,
    minLevel: 12,
    weight: 0.8,
  ),
  ChallengeTemplate(
    id: 'rule_flip',
    tag: ChallengeTag.trick,
    build: RuleFlipChallenge.new,
    minLevel: 14,
  ),
  ChallengeTemplate(
    id: 'tap_reverse_order',
    tag: ChallengeTag.trick,
    build: OrderChallenge.reverseBuild,
    minLevel: 17,
    weight: 0.8,
  ),
];

/// Id → template index for the deterministic rebuild path ([templateById]).
final Map<String, ChallengeTemplate> _templatesById = {
  for (final t in kChallengeTemplates) t.id: t,
};

/// Looks up a registered template by its stable [id]. Returns null for
/// unknown ids — callers (multiplayer hosts) must treat null as a bad round,
/// not a crash.
ChallengeTemplate? templateById(String id) => _templatesById[id];

/// Builds the canonical challenge for a multiplayer round from
/// `{ challengeId, seed }` (plus the round's [level] and, when the host has a
/// room language, [locale]).
///
/// This is the deterministic contract shared by the host, the simulation
/// harness and every phone ([`ROUND_START`] carries exactly this tuple —
/// see `docs/Gameplay/Multiplayer Challenges.md` and
/// `docs/Architecture/Multiplayer Protocol.md`):
///
/// ```dart
/// buildFromSeed(challengeId: 'tap_actual_color', seed: 28374, level: 12);
/// ```
///
/// Same tuple → same [Challenge] → same [ChallengeView] on every end. The rng
/// is seeded fresh from [seed] and never re-used across rounds, so nothing but
/// [seed] influences the outcome. `speed` is derived from the [level] via
/// [Difficulty.speedForLevel], exactly like the solo path, so both ends agree
/// on timings without the host sending an explicit speed.
///
/// This does **not** change single-player behaviour: [ChallengeGenerator]
/// remains the only solo entry point. Throws [ArgumentError] for an unknown
/// [challengeId].
///
/// NOTE (cross-language portability, decision logged in `docs/Meta/Decision
/// Log.md`): `Random(seed)` is deterministic within a given Dart runtime, so
/// every Dart end (Flutter phone, Dart harness) rebuilds identically. When the
/// native tvOS host lands (Phase 4), mirroring this exact seeded stream in
/// Swift is still an open decision: either the host reproduces the stream
/// identically, or it judges without a local rebuild.
Challenge buildFromSeed({
  required String challengeId,
  required int seed,
  required int level,
  AppLocale locale = AppLocale.en,
}) {
  final template = templateById(challengeId);
  if (template == null) {
    throw ArgumentError.value(
        challengeId, 'challengeId', 'template not found in registry');
  }
  final params = ChallengeParams(
    level: level,
    rng: Random(seed),
    speed: Difficulty.speedForLevel(level),
    locale: locale,
  );
  return template.build(params);
}
