import 'dart:math';

import '../core/challenge.dart';
import 'base.dart';

/// 13/14 — TAP TWICE / TAP EXACTLY 5 TIMES.
///
/// One tap short is a fail. One tap too many is a fail. There is a small
/// settle window so the player does not have to wait for the timer.
class ExactTapsChallenge extends BaseChallenge {
  ExactTapsChallenge(
    ChallengeParams p, {
    required this.required_,
    required String id,
    required Duration duration,
    required String instruction,
  }) : super(p, id: id, tag: ChallengeTag.counting, duration: duration) {
    this.instruction = instruction;
    layout = ChallengeLayout.single;
    targets = const [
      TargetSpec(id: 'pad', label: 'TAP', color: GameColor.slate, scale: 1.2),
    ];
    tapCounter = '0 / $required_';
  }

  final int required_;
  int _count = 0;
  Duration? _settleAt;

  static const _grace = Duration(milliseconds: 420);

  @override
  void onTap(TapInfo tap, ChallengeHost host) {
    if (tap.kind != TapKind.down) return;
    _count++;
    tapCounter = '$_count / $required_';
    if (_count > required_) {
      host.fail(reason: 'TOO MANY.');
      return;
    }
    if (_count == required_) {
      _settleAt = tap.elapsed + _grace;
    }
    host.invalidate();
  }

  @override
  void onTick(Duration elapsed, ChallengeHost host) {
    final settle = _settleAt;
    if (settle != null && elapsed >= settle && _count == required_) {
      host.pass();
    }
  }

  @override
  void onTimeout(ChallengeHost host) {
    if (_count == required_) {
      host.pass();
    } else {
      host.fail(reason: _count < required_ ? 'NOT ENOUGH.' : 'TOO MANY.');
    }
  }

  static ExactTapsChallenge twice(ChallengeParams p) => ExactTapsChallenge(
        p,
        required_: 2,
        id: 'tap_twice',
        duration: p.pace(const Duration(milliseconds: 2600), floorMs: 1400),
        instruction: 'TAP TWICE',
      );

  static ExactTapsChallenge exactly(ChallengeParams p) {
    final n = 3 + p.rng.nextInt(4); // 3..6
    return ExactTapsChallenge(
      p,
      required_: n,
      id: 'tap_exactly_n',
      duration: p.pace(const Duration(milliseconds: 3400), floorMs: 1800),
      instruction: 'TAP EXACTLY $n TIMES',
    );
  }
}

/// 15 — TAP AS FAST AS YOU CAN. Reach the count before the timer dies.
class SpamTapsChallenge extends BaseChallenge {
  SpamTapsChallenge(ChallengeParams p, this.goal)
      : super(
          p,
          id: 'spam_taps',
          tag: ChallengeTag.reaction,
          duration: p.pace(const Duration(milliseconds: 2600), floorMs: 1500),
        ) {
    instruction = 'TAP $goal TIMES. FAST.';
    layout = ChallengeLayout.single;
    targets = const [
      TargetSpec(id: 'pad', label: 'GO', color: GameColor.green, scale: 1.25),
    ];
    tapCounter = '0 / $goal';
  }

  final int goal;
  int _count = 0;

  @override
  void onTap(TapInfo tap, ChallengeHost host) {
    if (tap.kind != TapKind.down) return;
    _count++;
    tapCounter = '$_count / $goal';
    if (_count >= goal) {
      host.pass();
    } else {
      host.invalidate();
    }
  }

  @override
  void onTimeout(ChallengeHost host) => host.fail(reason: 'SLOW HANDS.');

  static SpamTapsChallenge build(ChallengeParams p) =>
      SpamTapsChallenge(p, 6 + min(6, p.level ~/ 5));
}

/// 16 — TAP 7.
TapTargetChallenge buildTapNumber(ChallengeParams p) {
  final options = <int>{};
  while (options.length < 4) {
    options.add(1 + p.rng.nextInt(9));
  }
  final list = p.shuffled(options.toList());
  final answer = p.pick(list);
  return TapTargetChallenge(
    p,
    id: 'tap_number',
    tag: ChallengeTag.counting,
    duration: p.pace(const Duration(milliseconds: 2200)),
    instruction: 'TAP $answer',
    targets: numberTargets(list),
    correctIds: {'n$answer'},
  );
}

/// 17 — TAP 2 + 3. Yes, people fail this.
TapTargetChallenge buildMath(ChallengeParams p) {
  final a = 1 + p.rng.nextInt(6);
  final b = 1 + p.rng.nextInt(6);
  final plus = p.chance(0.7) || a <= b;
  final answer = plus ? a + b : a - b;
  final options = <int>{answer};
  while (options.length < 4) {
    final noise = answer + (p.rng.nextInt(5) - 2);
    if (noise >= 0) options.add(noise);
  }
  final list = p.shuffled(options.toList());
  return TapTargetChallenge(
    p,
    id: 'math',
    tag: ChallengeTag.counting,
    duration: p.pace(const Duration(milliseconds: 3000), floorMs: 1400),
    instruction: plus ? 'TAP $a + $b' : 'TAP $a - $b',
    targets: numberTargets(list),
    correctIds: {'n$answer'},
    wrongReason: 'MATH. BASIC MATH.',
  );
}

/// 18 — HOW MANY CIRCLES? The shapes sit right above the answers.
TapTargetChallenge buildCountShapes(ChallengeParams p) {
  final circles = 2 + p.rng.nextInt(5); // 2..6
  final triangles = 1 + p.rng.nextInt(4);
  final soup = p.shuffled([
    ...List.filled(circles, '●'),
    ...List.filled(triangles, '▲'),
  ]).join(' ');

  final options = <int>{circles};
  while (options.length < 4) {
    final noise = circles + (p.rng.nextInt(5) - 2);
    if (noise > 0) options.add(noise);
  }
  final list = p.shuffled(options.toList());
  final challenge = TapTargetChallenge(
    p,
    id: 'count_shapes',
    tag: ChallengeTag.counting,
    duration: p.pace(const Duration(milliseconds: 4000), floorMs: 1800),
    instruction: 'HOW MANY CIRCLES?',
    targets: numberTargets(list),
    correctIds: {'n$circles'},
    layout: ChallengeLayout.grid2x2,
    wrongReason: 'COUNTING IS HARD, HUH.',
  );
  challenge.bigCenterText = soup;
  return challenge;
}
