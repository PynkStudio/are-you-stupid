import 'dart:math';

import '../core/challenge.dart';
import 'base.dart';

/// 34 — TAP LEFT. The buttons swap places while you reach for one.
class LeftRightSwapChallenge extends BaseChallenge {
  LeftRightSwapChallenge(ChallengeParams p)
      : super(
          p,
          id: 'left_right_swap',
          tag: ChallengeTag.trick,
          duration: p.pace(const Duration(milliseconds: 2600), floorMs: 1400),
        ) {
    _wantLeft = params.chance(0.5);
    instruction = _wantLeft ? 'TAP LEFT' : 'TAP RIGHT';
    layout = ChallengeLayout.row;
    targets = [
      const TargetSpec(id: 'a', color: GameColor.blue),
      const TargetSpec(id: 'b', color: GameColor.orange),
    ];
  }

  late final bool _wantLeft;
  late final Duration _swapAt = Duration(
    milliseconds: 380 + params.rng.nextInt(320),
  );
  bool _swapped = false;

  @override
  void onTick(Duration elapsed, ChallengeHost host) {
    if (!_swapped && elapsed >= _swapAt) {
      _swapped = true;
      targets = targets.reversed.toList();
      host.invalidate();
    }
  }

  @override
  void onTap(TapInfo tap, ChallengeHost host) {
    if (tap.kind != TapKind.down || tap.isBackground) return;
    final index = tap.index ?? 0;
    final tappedLeft = index == 0;
    if (tappedLeft == _wantLeft) {
      host.pass();
    } else {
      host.fail(reason: 'THEY MOVED. YOU DIDN\'T.');
    }
  }

  @override
  void onTimeout(ChallengeHost host) => host.fail(reason: 'TOO SLOW.');
}

/// 35 — the rule changes halfway through. Read again.
class RuleFlipChallenge extends BaseChallenge {
  RuleFlipChallenge(ChallengeParams p)
      : super(
          p,
          id: 'rule_flip',
          tag: ChallengeTag.trick,
          duration: p.pace(const Duration(milliseconds: 3200), floorMs: 1700),
        ) {
    final colors = params.shuffled(kBasicColors);
    _first = colors[0];
    _second = colors[1];
    instruction = 'TAP ${_first.label}';
    layout = ChallengeLayout.grid2x2;
    targets = honestColorTargets(colors);
  }

  late final GameColor _first;
  late final GameColor _second;
  late final Duration _flipAt = Duration(
    milliseconds: 700 + params.rng.nextInt(400),
  );
  bool _flipped = false;

  @override
  void onTick(Duration elapsed, ChallengeHost host) {
    if (!_flipped && elapsed >= _flipAt) {
      _flipped = true;
      instruction = 'TAP ${_second.label}';
      host.invalidate();
    }
  }

  @override
  void onTap(TapInfo tap, ChallengeHost host) {
    if (tap.kind != TapKind.down || tap.isBackground) return;
    final hit = targets.firstWhere((t) => t.id == tap.targetId);
    final wanted = _flipped ? _second : _first;
    if (hit.color == wanted) {
      host.pass();
    } else {
      host.fail(reason: _flipped ? 'IT CHANGED. READ.' : 'NOPE.');
    }
  }

  @override
  void onTimeout(ChallengeHost host) => host.fail(reason: 'TOO SLOW.');
}

/// 36 — IGNORE THE NEXT LINE. Then a perfectly good instruction shows up.
TapTargetChallenge buildIgnoreNext(ChallengeParams p) {
  final colors = p.shuffled(kBasicColors);
  final banned = p.pick(colors);
  final targets = honestColorTargets(colors);
  return TapTargetChallenge(
    p,
    id: 'ignore_next',
    tag: ChallengeTag.trick,
    duration: p.pace(const Duration(milliseconds: 3000), floorMs: 1600),
    instruction: 'IGNORE THE NEXT LINE',
    hint: 'TAP ${banned.label}',
    targets: targets,
    correctIds: {
      for (var i = 0; i < colors.length; i++)
        if (colors[i] != banned) targets[i].id,
    },
    wrongReason: 'YOU WERE TOLD TO IGNORE IT.',
    lateReason: 'IGNORING IS NOT FREEZING.',
  );
}

/// 37 — TAP AS FAST AS POSSIBLE. Terms and conditions apply.
class TooFastChallenge extends BaseChallenge {
  TooFastChallenge(ChallengeParams p)
      : super(
          p,
          id: 'too_fast',
          tag: ChallengeTag.trick,
          duration: const Duration(milliseconds: 2600),
        ) {
    instruction = 'TAP AS FAST AS POSSIBLE';
    layout = ChallengeLayout.single;
    targets = const [
      TargetSpec(id: 'pad', label: '', color: GameColor.slate, scale: 1.3),
    ];
  }

  static const _revealAt = Duration(milliseconds: 320);
  late final Duration _goAt = Duration(
    milliseconds: 1100 + params.rng.nextInt(500),
  );
  bool _go = false;

  @override
  void onTick(Duration elapsed, ChallengeHost host) {
    if (hint == null && elapsed >= _revealAt) {
      hint = '...AFTER THE GREEN LIGHT';
      host.invalidate();
    }
    if (!_go && elapsed >= _goAt) {
      _go = true;
      targets = const [
        TargetSpec(id: 'pad', label: 'GO', color: GameColor.green, scale: 1.3),
      ];
      host.invalidate();
    }
  }

  @override
  void onTap(TapInfo tap, ChallengeHost host) {
    if (tap.kind != TapKind.down) return;
    if (_go) {
      host.pass();
    } else {
      host.fail(reason: 'TOO FAST.');
    }
  }

  @override
  void onTimeout(ChallengeHost host) => host.fail(reason: 'TOO SLOW. IRONIC.');
}

/// 38/39 — TAP 1 → 2 → 3, or the exact opposite.
class OrderChallenge extends BaseChallenge {
  OrderChallenge(ChallengeParams p, this.ascending, this.count)
      : super(
          p,
          id: ascending ? 'tap_in_order' : 'tap_reverse_order',
          tag: ChallengeTag.trick,
          duration: p.pace(
            Duration(milliseconds: 1100 * count),
            floorMs: 1800,
          ),
        ) {
    instruction = ascending ? 'TAP 1 THEN 2 THEN 3' : 'TAP IN REVERSE ORDER';
    hint = ascending ? null : _sequence.join(' → ');
    layout = ChallengeLayout.grid2x2;
    final numbers = params.shuffled(List.generate(count, (i) => i + 1));
    targets = [
      for (final n in numbers)
        TargetSpec(id: 'o$n', label: '$n', color: GameColor.slate),
    ];
  }

  final bool ascending;
  final int count;
  int _step = 0;

  List<int> get _sequence => ascending
      ? List.generate(count, (i) => i + 1)
      : List.generate(count, (i) => count - i);

  @override
  void onTap(TapInfo tap, ChallengeHost host) {
    if (tap.kind != TapKind.down || tap.isBackground) return;
    final wanted = _sequence[_step];
    if (tap.targetId != 'o$wanted') {
      host.fail(reason: 'ORDER MATTERS.');
      return;
    }
    mutateTarget('o$wanted', (t) => t.copyWith(color: GameColor.green));
    _step++;
    if (_step >= _sequence.length) {
      host.pass();
    } else {
      host.invalidate();
    }
  }

  @override
  void onTimeout(ChallengeHost host) => host.fail(reason: 'TOO SLOW.');

  static OrderChallenge ascendingBuild(ChallengeParams p) =>
      OrderChallenge(p, true, 3);

  static OrderChallenge reverseBuild(ChallengeParams p) =>
      OrderChallenge(p, false, 3 + min(1, p.level ~/ 20));
}
