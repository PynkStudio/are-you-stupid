/// ChallengeMechanic — the controlled vocabulary for AI proposal generation.
///
/// Closed by construction: a proposal can only name a mechanic, action, trick
/// and shape that exist here, and the engine already knows how to render and
/// judge them ([[AI Challenge Generation]] → «ChallengeMechanic»). Anything
/// that is not in this vocabulary is rejected by the
/// [[AI Challenge Validator]] as unrenderable.
///
/// The v1 starter set mirrors the engine's existing challenge families; each
/// entry's *judging logic* (the engine behaviour behind the move) is engine
/// work that lands with the AI provider (Phase 5). What ships here is the
/// vocabulary: the closed enums, the contract metadata the validator enforces,
/// and the wire names.
///
/// This file is PURE DART: no Flutter imports ([[AI Challenge Validator]]).
library;

import '../core/challenge.dart';
import '../i18n/app_locale.dart';

/// The imperative a challenge's instruction must carry. Closed set.
enum AiAction {
  tap,
  tapMany,
  hold,
  doNotTap,
  tapSequence,
  tapUntilStop,
  colorPick;

  /// Wire name (`tap_many`, `donot_tap`, ...).
  String get wire => switch (this) {
        AiAction.tap => 'tap',
        AiAction.tapMany => 'tap_many',
        AiAction.hold => 'hold',
        AiAction.doNotTap => 'donot_tap',
        AiAction.tapSequence => 'tap_sequence',
        AiAction.tapUntilStop => 'tap_until_stop',
        AiAction.colorPick => 'color_pick',
      };

  /// null for anything outside the vocabulary.
  static AiAction? parse(String? value) => switch (value) {
        'tap' => AiAction.tap,
        'tap_many' => AiAction.tapMany,
        'hold' => AiAction.hold,
        'donot_tap' => AiAction.doNotTap,
        'tap_sequence' => AiAction.tapSequence,
        'tap_until_stop' => AiAction.tapUntilStop,
        'color_pick' => AiAction.colorPick,
        _ => null,
      };

  /// Verbs an instruction must contain for this action to read as the
  /// mechanic's imperative ([[AI Challenge Validator]] → instruction check).
  List<String> get imperativeVerbs => switch (this) {
        AiAction.tap => const ['TAP'],
        AiAction.tapMany => const ['TAP', 'EACH', 'ALL', 'EVERY'],
        AiAction.hold => const ['HOLD'],
        AiAction.doNotTap => const ['DON\'T', 'DONT', 'DO NOT', 'DO', 'AVOID'],
        AiAction.tapSequence => const ['TAP', 'REPEAT', 'ORDER', 'SEQUENCE'],
        AiAction.tapUntilStop => const ['TAP'],
        AiAction.colorPick => const ['TAP', 'SELECT', 'PICK'],
      };
}

/// The kind of play a mechanic produces. Closed set, descriptive — proposals
/// must name one and it must match the mechanic's registered kind.
enum AiKind {
  mixed,
  perception,
  sequence,
  trick,
  counting,
  ruleFlip,
  memory,
  hold,
  timing;

  String get wire => switch (this) {
        AiKind.mixed => 'mixed',
        AiKind.perception => 'perception',
        AiKind.sequence => 'sequence',
        AiKind.trick => 'trick',
        AiKind.counting => 'counting',
        AiKind.ruleFlip => 'rule_flip',
        AiKind.memory => 'memory',
        AiKind.hold => 'hold',
        AiKind.timing => 'timing',
      };

  static AiKind? parse(String? value) => switch (value) {
        'mixed' => AiKind.mixed,
        'perception' => AiKind.perception,
        'sequence' => AiKind.sequence,
        'trick' => AiKind.trick,
        'counting' => AiKind.counting,
        'rule_flip' => AiKind.ruleFlip,
        'memory' => AiKind.memory,
        'hold' => AiKind.hold,
        'timing' => AiKind.timing,
        _ => null,
      };
}

/// Trick variants a proposal may compose. Mirrors the scripted "tricks
/// unlock" ladder ([[Difficulty Curve]]): most are rejected while
/// `allowTricks` is false, `swap` being the gentle exception (see the
/// validator's trick contract).
enum AiTrickType {
  none,
  swap,
  fakeButton,
  sequence,
  ruleFlip,
  colorShifts,
  requiresAnomaly;

  String get wire => switch (this) {
        AiTrickType.none => 'none',
        AiTrickType.swap => 'swap',
        AiTrickType.fakeButton => 'fake_button',
        AiTrickType.sequence => 'sequence',
        AiTrickType.ruleFlip => 'rule_flip',
        AiTrickType.colorShifts => 'color_shifts',
        AiTrickType.requiresAnomaly => 'requires_anomaly',
      };

  static AiTrickType? parse(String? value) => switch (value) {
        'none' => AiTrickType.none,
        'swap' => AiTrickType.swap,
        'fake_button' => AiTrickType.fakeButton,
        'sequence' => AiTrickType.sequence,
        'rule_flip' => AiTrickType.ruleFlip,
        'color_shifts' => AiTrickType.colorShifts,
        'requires_anomaly' => AiTrickType.requiresAnomaly,
        _ => null,
      };

  /// Whether the engine needs this trick for the round to be playable.
  bool get isNone => this == AiTrickType.none;
}

/// Shapes the engine can render ([[Challenge System]]). The v1 vocabulary is
/// exactly `TargetShape` — a proposal naming anything else cannot be drawn and
/// is rejected as unrenderable.
enum AiShape {
  rect,
  circle,
  triangle,
  diamond;

  String get wire => name;

  static AiShape? parse(String? value) => switch (value) {
        'rect' => AiShape.rect,
        'circle' => AiShape.circle,
        'triangle' => AiShape.triangle,
        'diamond' => AiShape.diamond,
        _ => null,
      };

  /// This shape maps 1:1 to a renderable [TargetShape].
  TargetShape toTargetShape() => switch (this) {
        AiShape.rect => TargetShape.rect,
        AiShape.circle => TargetShape.circle,
        AiShape.triangle => TargetShape.triangle,
        AiShape.diamond => TargetShape.diamond,
      };
}

/// Semantic colors a proposal may use. Same set as the engine's [GameColor];
/// proposals may not invent new hues.
enum AiColor {
  red,
  blue,
  green,
  yellow,
  purple,
  orange,
  pink,
  white,
  slate;

  String get wire => name;

  static AiColor? parse(String? value) => switch (value) {
        'red' => AiColor.red,
        'blue' => AiColor.blue,
        'green' => AiColor.green,
        'yellow' => AiColor.yellow,
        'purple' => AiColor.purple,
        'orange' => AiColor.orange,
        'pink' => AiColor.pink,
        'white' => AiColor.white,
        'slate' => AiColor.slate,
        _ => null,
      };

  GameColor toGameColor() => switch (this) {
        AiColor.red => GameColor.red,
        AiColor.blue => GameColor.blue,
        AiColor.green => GameColor.green,
        AiColor.yellow => GameColor.yellow,
        AiColor.purple => GameColor.purple,
        AiColor.orange => GameColor.orange,
        AiColor.pink => GameColor.pink,
        AiColor.white => GameColor.white,
        AiColor.slate => GameColor.slate,
      };
}

/// The dims a sense decoy may play on, with the wire names proposals use.
enum AiSenseDecoy {
  color,
  label,
  shape,
  scale,
  rotation,
  opacity,
  position;

  String get wire => switch (this) {
        AiSenseDecoy.color => 'color',
        AiSenseDecoy.label => 'label',
        AiSenseDecoy.shape => 'shape',
        AiSenseDecoy.scale => 'size', // the docs' example uses "size"
        AiSenseDecoy.rotation => 'rotation',
        AiSenseDecoy.opacity => 'opacity',
        AiSenseDecoy.position => 'position',
      };

  /// Canonical dimension names the validator compares against element fields.
  /// "size" is accepted as an alias for [AiSenseDecoy.scale].
  static AiSenseDecoy? parse(String? value) => switch (value) {
        'color' => AiSenseDecoy.color,
        'label' => AiSenseDecoy.label,
        'shape' => AiSenseDecoy.shape,
        'size' || 'scale' => AiSenseDecoy.scale,
        'rotation' => AiSenseDecoy.rotation,
        'opacity' => AiSenseDecoy.opacity,
        'position' => AiSenseDecoy.position,
        _ => null,
      };
}

/// One mechanic in the controlled vocabulary, with the **judging contract**
/// the validator enforces ([[AI Challenge Validator]] → mechanic contract).
class ChallengeMechanic {
  const ChallengeMechanic({
    required this.move,
    required this.action,
    required this.kind,
    required this.senseDecoys,
    required this.floorMs,
    this.minElements = 2,
    this.maxElements = 6,
    this.requiresTrick = false,
    this.allowedTricks = const [AiTrickType.none],
    this.correctCount = 1,
    this.tag = ChallengeTag.color,
  }) : assert(correctCount != 0);

  /// Unique wire name, e.g. `tap_true_color`.
  final String move;

  /// The single imperative this mechanic's instruction must carry.
  final AiAction action;

  /// The kind of play; proposals must declare the same kind.
  final AiKind kind;

  /// The sense dimensions the mechanic plays on. Every declared dimension
  /// must be a *real* difference between the correct element and some decoy.
  final List<AiSenseDecoy> senseDecoys;

  /// Time floor in ms — the validator guarantees
  /// `timeLimitMs >= ceil(floorMs / Difficulty.speedForLevel(level))`
  /// exactly like the scripted `ChallengeParams.pace` floor
  /// ([[Difficulty Curve]]).
  final int floorMs;

  /// Element count bounds the proposal must respect.
  final int minElements;
  final int maxElements;

  /// When true the mechanic is only playable with a non-`none` trick AND
  /// `ctx.allowTricks`.
  final bool requiresTrick;

  /// The trick types this mechanic composes with (empty = only `none`).
  final List<AiTrickType> allowedTricks;

  /// How many elements are correct. `1` default; `null` means the mechanic's
  /// own judging logic decides (e.g. `tap_every_but`, `sequence_grow_remember`)
  /// and the element-bounds check skips the "exactly one" rule.
  final int? correctCount;

  /// Challenge family, for stats/debug parity with the scripted registry.
  final ChallengeTag tag;

  /// Wire `kind` string this mechanic is registered under.
  String get kindWire => kind.wire;

  /// The default locale-fallback fail line key the validator uses before a
  /// proposal's own per-locale lines. (Unused in v1: proposals ship their own
  /// `failLine` and the AI path stays English-only.)
  String get failLineKey => 'ai.$move.fail';
}

/// The v1 starter vocabulary — the nine mechanics from
/// [[AI Challenge Generation]] → «ChallengeMechanic».
const List<ChallengeMechanic> kMechanicVocabulary = [
  ChallengeMechanic(
    move: 'tap_true_color',
    action: AiAction.tap,
    kind: AiKind.mixed,
    senseDecoys: [AiSenseDecoy.color, AiSenseDecoy.label],
    floorMs: 900,
    allowedTricks: [AiTrickType.none, AiTrickType.swap],
    tag: ChallengeTag.color,
  ),
  ChallengeMechanic(
    move: 'tap_missing_color',
    action: AiAction.tap,
    kind: AiKind.perception,
    senseDecoys: [AiSenseDecoy.color],
    floorMs: 950,
    maxElements: 4,
    tag: ChallengeTag.perception,
  ),
  ChallengeMechanic(
    move: 'tap_second_order',
    action: AiAction.tap,
    kind: AiKind.sequence,
    senseDecoys: [AiSenseDecoy.position, AiSenseDecoy.shape],
    floorMs: 1000,
    allowedTricks: [AiTrickType.none, AiTrickType.ruleFlip],
    tag: ChallengeTag.counting,
  ),
  ChallengeMechanic(
    move: 'dont_tap_odd',
    action: AiAction.doNotTap,
    kind: AiKind.trick,
    senseDecoys: [AiSenseDecoy.shape, AiSenseDecoy.label],
    floorMs: 950,
    requiresTrick: true,
    allowedTricks: [
      AiTrickType.sequence,
      AiTrickType.ruleFlip,
      AiTrickType.fakeButton,
    ],
    tag: ChallengeTag.trick,
  ),
  ChallengeMechanic(
    move: 'tap_every_but',
    action: AiAction.tap,
    kind: AiKind.counting,
    senseDecoys: [AiSenseDecoy.color],
    floorMs: 1000,
    correctCount: null, // tap all-but-the-excluded one
    tag: ChallengeTag.counting,
  ),
  ChallengeMechanic(
    move: 'obey_once_then_flip',
    action: AiAction.tap,
    kind: AiKind.ruleFlip,
    senseDecoys: [AiSenseDecoy.label, AiSenseDecoy.color],
    floorMs: 1100,
    requiresTrick: true,
    allowedTricks: [AiTrickType.ruleFlip],
    tag: ChallengeTag.trick,
  ),
  ChallengeMechanic(
    move: 'sequence_grow_remember',
    action: AiAction.tapSequence,
    kind: AiKind.memory,
    senseDecoys: [AiSenseDecoy.position, AiSenseDecoy.shape],
    floorMs: 1200,
    correctCount: null, // each round's answer is the growing sequence's next step
    tag: ChallengeTag.memory,
  ),
  ChallengeMechanic(
    move: 'hold_true_color',
    action: AiAction.hold,
    kind: AiKind.hold,
    senseDecoys: [AiSenseDecoy.color],
    floorMs: 1100,
    allowedTricks: [AiTrickType.none, AiTrickType.swap],
    tag: ChallengeTag.reaction,
  ),
  ChallengeMechanic(
    move: 'spam_until_stop',
    action: AiAction.tapUntilStop,
    kind: AiKind.timing,
    senseDecoys: [],
    floorMs: 1200,
    correctCount: null,
    tag: ChallengeTag.reaction,
  ),
];

/// move → [ChallengeMechanic], for the validator's vocabulary lookup.
final Map<String, ChallengeMechanic> kMechanicByMove =
    {for (final m in kMechanicVocabulary) m.move: m};

/// The move ids eligible right now — backs `GetAvailableMechanicsTool`
/// ([[Dynamic Profiles and Tool Calling]]). The doc describes this as
/// "mechanics whose `minLevel <= level`", but unlike the scripted
/// `ChallengeTemplate` registry, [ChallengeMechanic] has no `minLevel`
/// field of its own yet — the v1 vocabulary only gates on tricks, so that's
/// the one real filter applied here: a `requiresTrick` mechanic is only
/// eligible when [allowTricks] is true.
List<String> availableMechanicMoves({required bool allowTricks}) => [
      for (final m in kMechanicVocabulary)
        if (!m.requiresTrick || allowTricks) m.move,
    ];

/// Whether the player rounding on this context is even in a locale the model
/// may output for. V1 ships English-only model output; every other locale
/// falls back to scripted ([[Localization and Language]]).
bool aiSupportedLocales(AppLocale locale) => locale == AppLocale.en;