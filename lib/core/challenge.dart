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

import '../i18n/app_locale.dart';
import '../i18n/spell_count_data.dart';
import '../i18n/strings.dart';

/// Semantic colors. Mapped to real Colors in `ui/theme.dart`.
enum GameColor { red, blue, green, yellow, purple, orange, pink, white, slate }

extension GameColorName on GameColor {
  /// English label. Challenges needing the *current* language must go
  /// through [ChallengeParams.colorLabel] instead — see
  /// `docs/Architecture/Localization.md`.
  String get label => Strings.t(AppLocale.en, 'color.$name');
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
    this.locale = AppLocale.en,
  });

  final int level;
  final Random rng;

  /// 1.0 at level 1, grows with level. Time limits are divided by it.
  final double speed;

  /// The player's current language. Defaults to English so every existing
  /// call site (tests included) keeps behaving exactly as before.
  final AppLocale locale;

  /// Looks up a translated string for the current [locale]. See
  /// `docs/Architecture/Localization.md` for the key naming convention.
  String tr(String key, [Map<String, String>? args]) =>
      Strings.t(locale, key, args);

  /// The color vocabulary word for [color] in the current [locale].
  String colorLabel(GameColor color) => Strings.t(locale, 'color.${color.name}');

  /// Language-specific gameplay word content for the word challenges
  /// (`tap_word_button`, `tap_nothing_button`, `odd_word_out`, `opposite`).
  /// These are re-authored per language, not machine-translated, so the
  /// gameplay stays equally fair in every locale.
  String get wordButtonTarget => tr('word.tap_word_button.target');

  List<String> get wordButtonDecoys =>
      Strings.list(locale, 'word.tap_word_button.decoy', 7);

  /// The "NOTHING / SOMETHING / EVERYTHING / a little" quartet. Index 0 is
  /// always the correct answer.
  List<String> get nothingWords =>
      Strings.list(locale, 'word.tap_nothing_button', 4);

  List<String> get oddWordIntruders =>
      Strings.list(locale, 'word.odd_word_out.intruder', 6);

  List<(String, String)> get oppositePairs => [
        for (var i = 0; i < 6; i++)
          () {
            final parts = tr('word.opposite.pair.$i').split('|');
            return (parts[0], parts[1]);
          }(),
      ];

  /// word -> letter count (the correct `spell_count` answer) in [locale].
  Map<String, int> get spellCountLetters =>
      kSpellCountLetters[locale] ?? kSpellCountLetters[AppLocale.en]!;

  /// word -> the number it names (the `spell_count` trap answer) in [locale].
  Map<String, int> get spellCountDigits =>
      kSpellCountDigits[locale] ?? kSpellCountDigits[AppLocale.en]!;

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
  void onTimeout(ChallengeHost host) =>
      host.fail(reason: params.tr('common.too_slow'));

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
