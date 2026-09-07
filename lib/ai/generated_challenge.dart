/// AI challenge portability model.
///
/// Two distinct objects live here:
///
/// - [GeneratedChallenge] — a **built, playable** challenge with provenance,
///   produced by a [ChallengeProvider]. The engine consumes this today
///   (Phase 1 seam).
/// - [ChallengeProposal] — the **portable, pre-build** wire form the model
///   produces and the [[AI Challenge Validator]] gates. A *validated*
///   proposal is later converted into a built [GeneratedChallenge] by the AI
///   provider (Phase 5) — elements map 1:1 to `TargetSpec`s, so no new
///   renderer ships for AI content ([[AI Challenge Generation]]).
///
/// This file is PURE DART: no Flutter imports.
library;

import '../core/challenge.dart';
import 'challenge_vocabulary.dart';

/// A mechanical element of a proposal, mirroring [TargetSpec] 1:1.
class AiElement {
  const AiElement({
    required this.id,
    this.label = '',
    required this.colorName,
    required this.shapeName,
    this.scale = 1.0,
    this.rotation = 0.0,
    this.dx = 0.0,
    this.dy = 0.0,
    this.opacity = 1.0,
    this.hidden = false,
  });

  final String id;
  final String label;

  /// Wire color name; unknown names are rejected by the validator as
  /// unrenderable ([AiColor.parse] yields null).
  final String colorName;
  final String shapeName;

  /// Size multiplier (1.0 = normal), clamped by the validator to real bounds.
  final double scale;

  /// Rotation in radians, magnitude ≤ 0.6 required.
  final double rotation;

  /// Wobble offset (fraction of target size), each within ±0.6 required.
  final double dx;
  final double dy;

  final double opacity;
  final bool hidden;

  /// Parsed, or null when [colorName] is outside the vocabulary.
  AiColor? get color => AiColor.parse(colorName);

  /// Parsed, or null when [shapeName] is outside the vocabulary.
  AiShape? get shape => AiShape.parse(shapeName);

  factory AiElement.fromJson(Map<String, dynamic> json) => AiElement(
        id: json['id'] as String,
        label: (json['label'] as String?) ?? '',
        colorName: json['color'] as String,
        shapeName: json['shape'] as String,
        scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
        rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
        dx: (json['dx'] as num?)?.toDouble() ?? 0.0,
        dy: (json['dy'] as num?)?.toDouble() ?? 0.0,
        opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
        hidden: (json['hidden'] as bool?) ?? false,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'label': label,
        'color': colorName,
        'shape': shapeName,
        'scale': scale,
        'rotation': rotation,
        'dx': dx,
        'dy': dy,
        'opacity': opacity,
        'hidden': hidden,
      };

  /// Whether the obvious sensed fields differ from [other] beyond rounding.
  bool differsFrom(AiElement other, {double epsilon = 0.01}) =>
      color != other.color ||
      label != other.label ||
      shape != other.shape ||
      (scale - other.scale).abs() > epsilon ||
      (rotation - other.rotation).abs() > epsilon ||
      (opacity - other.opacity).abs() > epsilon ||
      (dx - other.dx).abs() > epsilon ||
      (dy - other.dy).abs() > epsilon;
}

/// The mechanic block a proposal declares. Kept as proposed, so the validator
/// can require it to match the registry's contract for the same move.
class MechanicRef {
  const MechanicRef({
    required this.move,
    required this.action,
    required this.kind,
    this.senseDecoys = const [],
  });

  final String move;
  final String action;
  final String kind;
  final List<String> senseDecoys;

  factory MechanicRef.fromJson(Map<String, dynamic> json) => MechanicRef(
        move: json['move'] as String,
        action: json['action'] as String,
        kind: (json['kind'] as String?) ?? '',
        senseDecoys: [
          for (final s in (json['sense_decoys'] as List?) ?? const [])
            s as String,
        ],
      );

  Map<String, Object?> toJson() => {
        'move': move,
        'action': action,
        'kind': kind,
        'sense_decoys': senseDecoys,
      };
}

/// The winning input, exactly one.
class CorrectAnswer {
  const CorrectAnswer({required this.elementId, this.startsCorrect = false});

  /// Must resolve to an element id in the proposal.
  final String elementId;

  /// Meaningful for `swap` tricks: the correct element must *start* correct
  /// and swap away — a constant lie is rejected ([AI Challenge Validator]).
  final bool startsCorrect;

  factory CorrectAnswer.fromJson(Map<String, dynamic> json) => CorrectAnswer(
        elementId: json['elementId'] as String,
        startsCorrect: (json['startsCorrect'] as bool?) ?? false,
      );

  Map<String, Object?> toJson() =>
      {'elementId': elementId, 'startsCorrect': startsCorrect};
}

/// The tension read-outs the model fills for a mechanic.
class DifficultySpec {
  const DifficultySpec({
    required this.level,
    required this.timeLimitMs,
    required this.trickTypeName,
  });

  /// The round the proposal was written for (informational — the validator
  /// gates by the *context*'s level, see [[Player Telemetry and Adaptive
  /// Difficulty]] → levels).
  final int level;

  /// The round length the model proposes. Validator enforces floors and the
  /// 8000 ms cap.
  final int timeLimitMs;

  /// Wire trick name; null-parseable values are rejected as unrenderable.
  final String trickTypeName;

  AiTrickType? get trickType => AiTrickType.parse(trickTypeName);

  factory DifficultySpec.fromJson(Map<String, dynamic> json) => DifficultySpec(
        level: json['level'] as int,
        timeLimitMs: json['timeLimitMs'] as int,
        trickTypeName: (json['trickType'] as String?) ?? 'none',
      );

  Map<String, Object?> toJson() =>
      {'level': level, 'timeLimitMs': timeLimitMs, 'trickType': trickTypeName};
}

/// The model's pre-validation proposal, in the portable wire shape
/// ([[AI Challenge Generation]] → «GeneratedChallenge»).
///
/// `fromJson` throws [FormatException] on structurally broken envelopes — the
/// bridge converts that into a `decodingFailure` result. Content problems (bad
/// ids, wrong words, out-of-bounds values, tone) are NOT exceptions: they are
/// verdicts from the [[AI Challenge Validator]].
class ChallengeProposal {
  ChallengeProposal({
    required this.id,
    required this.mechanic,
    required this.instruction,
    required this.elements,
    required this.correctAnswer,
    required this.difficulty,
    required this.failLine,
    required this.seed,
    String? source,
  }) : source = source ?? 'ai';

  /// `ai.` + 5-char base36 ([[AI Challenge Generation]]).
  final String id;

  final MechanicRef mechanic;

  /// < 8 words, uppercase, in the player's locale.
  final String instruction;

  final List<AiElement> elements;

  final CorrectAnswer correctAnswer;

  final DifficultySpec difficulty;

  /// Per-locale ("en", ...) → the one fail line shown on failure.
  final Map<String, String> failLine;

  /// Drives the rng-backed layout for determinism ([[Multiplayer AI Director]]).
  /// 0 = the provider decides (solo).
  final int seed;

  /// Always `ai` for model output; anything else fails the envelope check.
  final String source;

  /// The registry entry for [mechanic.move], or null when the move is outside
  /// the vocabulary (unrenderable — validator's exitChallenge).
  ChallengeMechanic? get mechanicContract => kMechanicByMove[mechanic.move];

  /// The correct element, or null when it does not resolve.
  AiElement? get correctElement {
    for (final e in elements) {
      if (e.id == correctAnswer.elementId) return e;
    }
    return null;
  }

  factory ChallengeProposal.fromJson(Map<String, dynamic> json) {
    final mechanic = json['mechanic'];
    final elements = json['elements'];
    final correctAnswer = json['correctAnswer'];
    final difficulty = json['difficulty'];
    final failLine = json['failLine'];
    if (mechanic is! Map<String, dynamic> ||
        elements is! List ||
        correctAnswer is! Map<String, dynamic> ||
        difficulty is! Map<String, dynamic> ||
        failLine is! Map<String, dynamic>) {
      throw const FormatException('ChallengeProposal: broken envelope');
    }
    final id = json['id'];
    if (id is! String || id.isEmpty) {
      throw const FormatException('ChallengeProposal: missing id');
    }
    return ChallengeProposal(
      id: id,
      mechanic: MechanicRef.fromJson(mechanic),
      instruction: (json['instruction'] as String?) ?? '',
      elements: [
        for (final e in elements)
          if (e is Map<String, dynamic>) AiElement.fromJson(e),
      ],
      correctAnswer: CorrectAnswer.fromJson(correctAnswer),
      difficulty: DifficultySpec.fromJson(difficulty),
      failLine: {
        for (final e in failLine.entries) e.key.toString(): e.value.toString(),
      },
      seed: (json['seed'] as num?)?.toInt() ?? 0,
      source: (json['source'] as String?) ?? 'ai',
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'mechanic': mechanic.toJson(),
        'instruction': instruction,
        'elements': [for (final e in elements) e.toJson()],
        'correctAnswer': correctAnswer.toJson(),
        'difficulty': difficulty.toJson(),
        'failLine': failLine,
        'seed': seed,
        'source': source,
      };
}

/// A challenge produced by a [ChallengeProvider], wrapped with provenance.
class GeneratedChallenge {
  GeneratedChallenge({
    required this.challenge,
    required this.source,
    String? id,
    int? seed,
  })  : id = id ?? challenge.id,
        seed = seed ?? 0;

  /// The built, playable challenge.
  final Challenge challenge;

  /// Where this challenge came from: `scripted` today, `ai` once the model
  /// path lands. The engine never branches on it — telemetry and debug
  /// captures only ([[Privacy and Offline]]).
  final String source;

  /// Stable id. AI proposals are prefixed `ai.` ([[AI Challenge Generation]]).
  final String id;

  /// Determinism seed for multiplayer rounds ([[Multiplayer AI Director]]).
  /// 0 = the provider's own randomness (solo).
  final int seed;
}