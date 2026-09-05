import 'dart:math';

import '../core/challenge.dart';
import 'base.dart';

/// 30 — four almost identical shapes. One is slightly off.
TapTargetChallenge buildSpotDifferent(ChallengeParams p) {
  final shape = p.pick(TargetShape.values);
  final color = p.pick(kWideColors);
  final odd = p.rng.nextInt(4);
  final heat = (p.level / 34).clamp(0.0, 1.0);
  final delta = 0.22 - 0.13 * heat; // gets meaner, never invisible
  final rotate = p.chance(0.4);

  final targets = [
    for (var i = 0; i < 4; i++)
      TargetSpec(
        id: 's$i',
        shape: shape,
        color: color,
        scale: i == odd && !rotate ? 1 - delta : 1.0,
        rotation: i == odd && rotate ? delta : 0.0,
      ),
  ];

  return TapTargetChallenge(
    p,
    id: 'spot_different',
    tag: ChallengeTag.perception,
    duration: p.pace(const Duration(milliseconds: 3200), floorMs: 1500),
    instruction: 'TAP THE DIFFERENT ONE',
    targets: targets,
    correctIds: {'s$odd'},
    wrongReason: 'LOOK CLOSER.',
  );
}

/// 31 — two identical buttons. One of them changes. Tap the other one.
class DidntChangeChallenge extends BaseChallenge {
  DidntChangeChallenge(ChallengeParams p)
      : super(
          p,
          id: 'didnt_change',
          tag: ChallengeTag.perception,
          duration: p.pace(const Duration(milliseconds: 3000), floorMs: 1600),
        ) {
    final base = params.pick(kWideColors);
    _other = params.pick(kWideColors.where((c) => c != base).toList());
    _changing = params.rng.nextInt(2);
    instruction = "TAP THE ONE THAT DIDN'T CHANGE";
    layout = ChallengeLayout.row;
    targets = [
      TargetSpec(id: 'a', color: base),
      TargetSpec(id: 'b', color: base),
    ];
  }

  late final GameColor _other;
  late final int _changing;
  late final Duration _changeAt = Duration(
    milliseconds: 500 + params.rng.nextInt(500),
  );
  bool _changed = false;

  @override
  void onTick(Duration elapsed, ChallengeHost host) {
    if (!_changed && elapsed >= _changeAt) {
      _changed = true;
      final id = _changing == 0 ? 'a' : 'b';
      mutateTarget(id, (t) => t.copyWith(color: _other));
      host.invalidate();
    }
  }

  @override
  void onTap(TapInfo tap, ChallengeHost host) {
    if (tap.kind != TapKind.down || tap.isBackground) return;
    if (!_changed) {
      host.fail(reason: 'WAIT FOR IT.');
      return;
    }
    final correct = _changing == 0 ? 'b' : 'a';
    if (tap.targetId == correct) {
      host.pass();
    } else {
      host.fail(reason: 'THAT ONE CHANGED.');
    }
  }

  @override
  void onTimeout(ChallengeHost host) => host.fail(reason: 'TOO SLOW.');
}

/// 32 — TAP THE BIGGEST / SMALLEST.
TapTargetChallenge buildSizeCompare(ChallengeParams p) {
  final biggest = p.chance(0.5);
  final scales = <double>[];
  while (scales.length < 4) {
    final s = 0.55 + p.rng.nextDouble() * 0.6;
    if (scales.every((v) => (v - s).abs() > 0.09)) scales.add(s);
  }
  final color = p.pick(kWideColors);
  final targets = [
    for (var i = 0; i < 4; i++)
      TargetSpec(
        id: 'z$i',
        shape: TargetShape.circle,
        color: color,
        scale: scales[i],
      ),
  ];
  final wanted = biggest
      ? scales.indexOf(scales.reduce(max))
      : scales.indexOf(scales.reduce(min));
  return TapTargetChallenge(
    p,
    id: 'size_compare',
    tag: ChallengeTag.perception,
    duration: p.pace(const Duration(milliseconds: 2400), floorMs: 1200),
    instruction: biggest ? 'TAP THE BIGGEST' : 'TAP THE SMALLEST',
    targets: targets,
    correctIds: {'z$wanted'},
    wrongReason: 'SIZE. IT WAS ABOUT SIZE.',
  );
}

/// 33 — most of these buttons are decoration.
TapTargetChallenge buildFakeButtons(ChallengeParams p) {
  final real = p.rng.nextInt(6);
  final color = p.pick(kWideColors);
  final targets = [
    for (var i = 0; i < 6; i++)
      TargetSpec(
        id: 'f$i',
        label: 'BUTTON',
        color: color,
        opacity: i == real ? 1.0 : 0.32,
      ),
  ];
  return TapTargetChallenge(
    p,
    id: 'fake_buttons',
    tag: ChallengeTag.perception,
    duration: p.pace(const Duration(milliseconds: 2600), floorMs: 1300),
    instruction: 'TAP THE REAL BUTTON',
    targets: targets,
    correctIds: {'f$real'},
    layout: ChallengeLayout.grid3,
    wrongReason: 'THAT ONE WAS PAINT.',
  );
}
