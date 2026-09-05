/// Core challenge model.
///
/// This file is PURE DART on purpose: no Flutter imports.
/// Challenges describe *what* to show ([ChallengeView]) and decide *what a tap
/// means*. They never build widgets. Rendering is the renderer's job.
///
/// Adding a new challenge = writing one [Challenge] subclass + registering a
/// [ChallengeTemplate]. Nothing else in the codebase needs to change.
library;

import 'dart:math';

/// Semantic colors. Mapped to real Colors in `ui/theme.dart`.
enum GameColor { red, blue, green, yellow, purple, orange, pink, white, slate }

extension GameColorName on GameColor {
  String get label => switch (this) {
        GameColor.red => 'RED',
        GameColor.blue => 'BLUE',
        GameColor.green => 'GREEN',
        GameColor.yellow => 'YELLOW',
        GameColor.purple => 'PURPLE',
        GameColor.orange => 'ORANGE',
        GameColor.pink => 'PINK',
        GameColor.white => 'WHITE',
        GameColor.slate => 'GREY',
      };
}

/// The four colors used by the "easy" color challenges.
const kBasicColors = [
  GameColor.red,
  GameColor.blue,
  GameColor.green,
  GameColor.yellow,
];

/// Full pool used when we want visual noise.
const kWideColors = [
  GameColor.red,
  GameColor.blue,
  GameColor.green,
  GameColor.yellow,
  GameColor.purple,
  GameColor.orange,
  GameColor.pink,
];

enum TargetShape { rect, circle, triangle, diamond }

/// How the renderer arranges the targets.
enum ChallengeLayout {
  /// 2x2 grid of huge buttons.
  grid2x2,

  /// 3 columns, up to 2 rows.
  grid3,

  /// A single horizontal row (left / right).
  row,

  /// One giant centered button.
  single,

  /// Nothing to tap. The whole screen is the tap area.
  none,

  /// Free positioning using [TargetSpec.x] / [TargetSpec.y].
  free,
}

/// A tappable thing on screen.
class TargetSpec {
  const TargetSpec({
    required this.id,
    this.label = '',
    this.color = GameColor.slate,
    this.shape = TargetShape.rect,
    this.scale = 1.0,
    this.rotation = 0.0,
    this.dx = 0.0,
    this.dy = 0.0,
    this.x = 0.5,
    this.y = 0.5,
    this.opacity = 1.0,
    this.hidden = false,
    this.textColor,
  });

  final String id;
  final String label;
  final GameColor color;
  final TargetShape shape;

  /// Size multiplier (1.0 = normal).
  final double scale;

  /// Rotation in radians.
  final double rotation;

  /// Wobble offset, in fractions of the target size. Used by "moving" traps.
  final double dx;
  final double dy;

  /// Position (0..1) inside the play area. Only used by [ChallengeLayout.free].
  final double x;
  final double y;

  final double opacity;
  final bool hidden;

  /// Overrides the automatic label color.
  final GameColor? textColor;

  TargetSpec copyWith({
    String? id,
    String? label,
    GameColor? color,
    TargetShape? shape,
    double? scale,
    double? rotation,
    double? dx,
    double? dy,
    double? x,
    double? y,
    double? opacity,
    bool? hidden,
    GameColor? textColor,
  }) {
    return TargetSpec(
      id: id ?? this.id,
      label: label ?? this.label,
      color: color ?? this.color,
      shape: shape ?? this.shape,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
      dx: dx ?? this.dx,
      dy: dy ?? this.dy,
      x: x ?? this.x,
      y: y ?? this.y,
      opacity: opacity ?? this.opacity,
      hidden: hidden ?? this.hidden,
      textColor: textColor ?? this.textColor,
    );
  }
}

/// Everything the renderer needs to draw one frame of a challenge.
class ChallengeView {
  const ChallengeView({
    required this.instruction,
    this.layout = ChallengeLayout.none,
    this.targets = const [],
    this.hint,
    this.bigCenterText,
    this.blackout = false,
    this.showTimer = true,
    this.pressure = 0.0,
    this.tapCounter,
  });

  /// Short. Under 8 words. Always uppercase on screen.
  final String instruction;

  final ChallengeLayout layout;
  final List<TargetSpec> targets;

  /// Small secondary line under the instruction.
  final String? hint;

  /// Huge text in the middle of the play area (e.g. "NOW", "3").
  final String? bigCenterText;

  /// Hides the play area content (memory challenges).
  final bool blackout;

  /// Whether the countdown bar is visible.
  final bool showTimer;

  /// 0..1 — renderer adds visual noise / pulsing. Pure psychological pressure.
  final double pressure;

  /// Optional live counter, e.g. taps done so far.
  final String? tapCounter;
}

/// Input is judged on pointer DOWN: the game must feel instant.
/// [TapKind.up] exists only for hold-style challenges.
enum TapKind { down, up }

class TapInfo {
  const TapInfo({
    required this.targetId,
    required this.elapsed,
    this.kind = TapKind.down,
    this.index,
  });

  /// null => the player tapped the background, not a target.
  final String? targetId;

  /// Time since the round started.
  final Duration elapsed;

  final TapKind kind;

  /// Visual index of the tapped target (0 = leftmost/first). Useful for
  /// position based challenges ("TAP LEFT").
  final int? index;

  bool get isBackground => targetId == null;
}

/// What a [Challenge] can do to the run.
abstract class ChallengeHost {
  /// The player did the right thing. Advance.
  void pass({String? note});

  /// The player blew it.
  void fail({String? reason});

  /// The view changed; repaint.
  void invalidate();
}

/// Category, used for weighting and for stats/debug only.
enum ChallengeTag {
  color,
  word,
  patience,
  counting,
  memory,
  reaction,
  perception,
  trick,
}

/// Per-round construction context.
class ChallengeParams {
  ChallengeParams({
    required this.level,
    required this.rng,
    required this.speed,
  });

  final int level;
  final Random rng;

  /// 1.0 at level 1, grows with level. Time limits are divided by it.
  final double speed;

  /// Scales a base duration by the current speed, with a sane floor.
  Duration pace(Duration base, {int floorMs = 700}) {
    final ms = (base.inMilliseconds / speed).round();
    return Duration(milliseconds: max(floorMs, ms));
  }

  T pick<T>(List<T> items) => items[rng.nextInt(items.length)];

  List<T> shuffled<T>(List<T> items) {
    final copy = [...items];
    copy.shuffle(rng);
    return copy;
  }

  /// True with probability [p].
  bool chance(double p) => rng.nextDouble() < p;
}

/// One micro-challenge instance. Lives for one round only.
abstract class Challenge {
  Challenge(this.params);

  final ChallengeParams params;

  /// Stable id of the template (for stats / dedupe).
  String get id;

  ChallengeTag get tag;

  /// Round length. When it expires [onTimeout] fires.
  Duration get duration;

  /// Current frame.
  ChallengeView get view;

  /// Called once, right before the first frame.
  void onStart(ChallengeHost host) {}

  /// Called ~60x/second with the time since the round started.
  void onTick(Duration elapsed, ChallengeHost host) {}

  /// A tap happened. Decide.
  void onTap(TapInfo tap, ChallengeHost host);

  /// Timer ran out. Most challenges fail here; patience ones pass.
  void onTimeout(ChallengeHost host) => host.fail(reason: 'TOO SLOW.');

  /// Extra text shown on the "correct" flash, e.g. "+0.13s".
  String? get successNote => null;
}

/// A registered challenge template.
class ChallengeTemplate {
  const ChallengeTemplate({
    required this.id,
    required this.tag,
    required this.build,
    this.minLevel = 1,
    this.weight = 1.0,
    this.starter = false,
  });

  final String id;
  final ChallengeTag tag;
  final Challenge Function(ChallengeParams params) build;

  /// Never appears before this level.
  final int minLevel;

  /// Relative pick probability.
  final double weight;

  /// Can be used for the very first levels (must be dead simple + fair).
  final bool starter;
}
