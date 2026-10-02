import 'dart:math';

import '../core/challenge.dart';
import 'base.dart';

/// 1 — TAP RED. The honest one. Labels match paint.
TapTargetChallenge buildTapColor(ChallengeParams p) {
  final colors = p.shuffled(kBasicColors);
  final target = p.pick(colors);
  final targets = honestColorTargets(colors, p.locale);
  final correct = targets[colors.indexOf(target)].id;
  return TapTargetChallenge(
    p,
    id: 'tap_color',
    tag: ChallengeTag.color,
    duration: p.pace(const Duration(milliseconds: 2200)),
    instruction: p.tr(
      'challenge.tap_color.instruction',
      {'color': p.colorLabel(target)},
    ),
    targets: targets,
    correctIds: {correct},
  );
}

/// 2 — same, but the buttons will not sit still.
class MovingColorChallenge extends TapTargetChallenge {
  MovingColorChallenge(
    ChallengeParams p, {
    required super.instruction,
    required super.targets,
    required super.correctIds,
  }) : super(
          p,
          id: 'tap_color_moving',
          tag: ChallengeTag.color,
          duration: p.pace(const Duration(milliseconds: 2600)),
        );

  late final List<double> _phases = [
    for (var i = 0; i < targets.length; i++) i * 1.7 + params.rng.nextDouble()
  ];

  @override
  void onTick(Duration elapsed, ChallengeHost host) {
    final t = elapsed.inMilliseconds / 1000.0;
    final swing = 0.10 + 0.14 * (params.level / 30).clamp(0.0, 1.0);
    targets = [
      for (var i = 0; i < targets.length; i++)
        targets[i].copyWith(
          dx: swing * sin(t * 3.1 + _phases[i]),
          dy: swing * 0.6 * cos(t * 2.4 + _phases[i]),
        ),
    ];
    host.invalidate();
  }

  static MovingColorChallenge build(ChallengeParams p) {
    final colors = p.shuffled(kBasicColors);
    final target = p.pick(colors);
    final targets = honestColorTargets(colors, p.locale);
    return MovingColorChallenge(
      p,
      instruction: p.tr(
        'challenge.tap_color_moving.instruction',
        {'color': p.colorLabel(target)},
      ),
      targets: targets,
      correctIds: {targets[colors.indexOf(target)].id},
    );
  }
}

/// Builds a set of buttons where paint and word deliberately disagree.
({List<TargetSpec> targets, int paintIndex, int wordIndex, GameColor color})
    _conflictingSet(ChallengeParams p) {
  final paints = p.shuffled(kBasicColors);
  final color = p.pick(paints);
  final paintIndex = paints.indexOf(color);

  // Words: same pool, but the word for [color] must land on another button.
  var words = p.shuffled(kBasicColors);
  var guard = 0;
  while (words.indexOf(color) == paintIndex && guard++ < 20) {
    words = p.shuffled(kBasicColors);
  }
  final wordIndex = words.indexOf(color);
  return (
    targets: mixedColorTargets(paints, words, p.locale),
    paintIndex: paintIndex,
    wordIndex: wordIndex,
    color: color,
  );
}

/// 3 — TAP BLUE, where one button *says* blue and another *is* blue.
/// The instruction names a color → the paint wins.
TapTargetChallenge buildTapActualColor(ChallengeParams p) {
  final set = _conflictingSet(p);
  return TapTargetChallenge(
    p,
    id: 'tap_actual_color',
    tag: ChallengeTag.color,
    duration: p.pace(const Duration(milliseconds: 2400)),
    instruction: p.tr(
      'challenge.tap_actual_color.instruction',
      {'color': p.colorLabel(set.color)},
    ),
    targets: set.targets,
    correctIds: {set.targets[set.paintIndex].id},
    wrongReason: p.tr('challenge.tap_actual_color.wrong'),
  );
}

/// 4 — TAP THE BUTTON THAT SAYS BLUE. The word wins.
TapTargetChallenge buildTapTheWord(ChallengeParams p) {
  final set = _conflictingSet(p);
  return TapTargetChallenge(
    p,
    id: 'tap_the_word',
    tag: ChallengeTag.word,
    duration: p.pace(const Duration(milliseconds: 2600)),
    instruction: p.tr(
      'challenge.tap_the_word.instruction',
      {'color': p.colorLabel(set.color)},
    ),
    targets: set.targets,
    correctIds: {set.targets[set.wordIndex].id},
    wrongReason: p.tr('challenge.tap_the_word.wrong'),
  );
}

/// 5 — DON'T TAP RED. Anything else is fine. Doing nothing is not.
TapTargetChallenge buildDontTapColor(ChallengeParams p) {
  final colors = p.shuffled(kBasicColors);
  final banned = p.pick(colors);
  final targets = honestColorTargets(colors, p.locale);
  final correct = <String>{
    for (var i = 0; i < colors.length; i++)
      if (colors[i] != banned) targets[i].id,
  };
  return TapTargetChallenge(
    p,
    id: 'dont_tap_color',
    tag: ChallengeTag.color,
    duration: p.pace(const Duration(milliseconds: 2400)),
    instruction: p.tr(
      'challenge.dont_tap_color.instruction',
      {'color': p.colorLabel(banned)},
    ),
    targets: targets,
    correctIds: correct,
    wrongReason: p.tr('challenge.dont_tap_color.wrong'),
    lateReason: p.tr('challenge.dont_tap_color.late'),
  );
}

/// 6 — DON'T TAP RED, while every button keeps repainting itself.
class ShiftingColorsChallenge extends BaseChallenge {
  ShiftingColorsChallenge(ChallengeParams p)
      : super(
          p,
          id: 'dont_tap_color_shifting',
          tag: ChallengeTag.color,
          duration: p.pace(const Duration(milliseconds: 3200), floorMs: 1500),
        ) {
    instruction = p.tr(
      'challenge.dont_tap_color_shifting.instruction',
      {'color': p.colorLabel(GameColor.red)},
    );
    hint = p.tr('challenge.dont_tap_color_shifting.hint');
    layout = ChallengeLayout.grid2x2;
    _repaint();
  }

  Duration _lastShift = Duration.zero;
  late final Duration _interval = Duration(
    milliseconds: max(260, (700 / params.speed).round()),
  );

  void _repaint() {
    final pool = [...kBasicColors];
    final colors = params.shuffled(pool);
    targets = [
      for (var i = 0; i < 4; i++) TargetSpec(id: 'c$i', color: colors[i]),
    ];
  }

  @override
  void onTick(Duration elapsed, ChallengeHost host) {
    if (elapsed - _lastShift >= _interval) {
      _lastShift = elapsed;
      _repaint();
      host.invalidate();
    }
  }

  @override
  void onTap(TapInfo tap, ChallengeHost host) {
    if (tap.kind != TapKind.down || tap.isBackground) return;
    final hit = targetById(tap.targetId);
    if (hit == null) return;
    if (hit.color == GameColor.red) {
      host.fail(
        reason: params.tr(
          'challenge.dont_tap_color_shifting.wrong',
          {'color': params.colorLabel(GameColor.red)},
        ),
      );
    } else {
      host.pass();
    }
  }

  @override
  void onTimeout(ChallengeHost host) => host.fail(
        reason: params.tr('challenge.dont_tap_color_shifting.late'),
      );
}

/// 7 — four color words, four paints, one paint nobody wrote down.
TapTargetChallenge buildUnwrittenColor(ChallengeParams p) {
  final paints = p.shuffled(kBasicColors);
  final odd = p.pick(paints);
  // Words cover every color except [odd]; the leftover slot repeats one word.
  final others = paints.where((c) => c != odd).toList();
  final words = p.shuffled([...others, p.pick(others)]);
  final targets = mixedColorTargets(paints, words, p.locale);
  return TapTargetChallenge(
    p,
    id: 'tap_unwritten_color',
    tag: ChallengeTag.word,
    duration: p.pace(const Duration(milliseconds: 3400), floorMs: 1400),
    instruction: p.tr('challenge.tap_unwritten_color.instruction'),
    targets: targets,
    correctIds: {targets[paints.indexOf(odd)].id},
    wrongReason: p.tr('challenge.tap_unwritten_color.wrong'),
  );
}
