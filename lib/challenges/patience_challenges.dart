import 'dart:math';

import '../core/challenge.dart';
import 'base.dart';

/// 19 — DON'T TAP ANYTHING. Then a huge TAP ME button shows up. Obviously.
class DontTapChallenge extends BaseChallenge {
  DontTapChallenge(ChallengeParams p)
      : super(
          p,
          id: 'dont_tap',
          tag: ChallengeTag.patience,
          duration: p.pace(const Duration(milliseconds: 2900), floorMs: 1800),
        ) {
    instruction = p.tr('challenge.dont_tap.instruction');
    layout = ChallengeLayout.none;
    _bait = p.tr('challenge.dont_tap.bait');
  }

  late final String _bait;
  late final Duration _baitAt = Duration(
    milliseconds: (duration.inMilliseconds * 0.42).round(),
  );
  bool _baited = false;

  @override
  void onTick(Duration elapsed, ChallengeHost host) {
    if (!_baited && elapsed >= _baitAt) {
      _baited = true;
      layout = ChallengeLayout.single;
      targets = [
        TargetSpec(
          id: 'bait',
          label: _bait,
          color: GameColor.green,
          scale: 1.3,
        ),
      ];
      host.invalidate();
    }
  }

  @override
  void onTap(TapInfo tap, ChallengeHost host) {
    if (tap.kind == TapKind.up) return;
    host.fail(reason: params.tr('common.one_job'));
  }

  @override
  void onTimeout(ChallengeHost host) =>
      host.pass(note: params.tr('challenge.dont_tap.success'));
}

/// 20 — DO NOTHING, while the screen does everything it can to make you tap.
class DoNothingChallenge extends BaseChallenge {
  DoNothingChallenge(ChallengeParams p)
      : super(
          p,
          id: 'do_nothing',
          tag: ChallengeTag.patience,
          duration: p.pace(const Duration(milliseconds: 3000), floorMs: 2000),
        ) {
    instruction = p.tr('challenge.do_nothing.instruction');
    layout = ChallengeLayout.none;
    note = p.tr('challenge.do_nothing.success');
  }

  @override
  void onTick(Duration elapsed, ChallengeHost host) {
    final t = elapsed.inMilliseconds / duration.inMilliseconds;
    pressure = t.clamp(0.0, 1.0);
    final left = duration - elapsed;
    final secs = (left.inMilliseconds / 1000).ceil();
    final next = secs > 0 ? '$secs' : null;
    if (next != bigCenterText) {
      bigCenterText = next;
    }
    host.invalidate();
  }

  @override
  void onTap(TapInfo tap, ChallengeHost host) {
    if (tap.kind == TapKind.up) return;
    host.fail(reason: params.tr('challenge.do_nothing.wrong'));
  }

  @override
  void onTimeout(ChallengeHost host) =>
      host.pass(note: params.tr('challenge.do_nothing.success'));
}

/// 21 — WAIT FOR GREEN. Tapping early is the whole point.
class WaitForGreenChallenge extends BaseChallenge {
  WaitForGreenChallenge(ChallengeParams p, this._greenAt, Duration window)
      : super(
          p,
          id: 'wait_for_green',
          tag: ChallengeTag.reaction,
          duration: _greenAt + window,
        ) {
    instruction = p.tr('challenge.wait_for_green.instruction');
    layout = ChallengeLayout.single;
    targets = const [
      TargetSpec(id: 'pad', label: '', color: GameColor.slate, scale: 1.35),
    ];
  }

  final Duration _greenAt;
  bool _green = false;

  @override
  void onTick(Duration elapsed, ChallengeHost host) {
    if (!_green && elapsed >= _greenAt) {
      _green = true;
      final now = params.tr('common.now_label');
      instruction = now;
      targets = [
        TargetSpec(id: 'pad', label: now, color: GameColor.green, scale: 1.35),
      ];
      host.invalidate();
    }
  }

  @override
  void onTap(TapInfo tap, ChallengeHost host) {
    if (tap.kind != TapKind.down) return;
    if (_green) {
      host.pass();
    } else {
      host.fail(reason: params.tr('challenge.wait_for_green.wrong'));
    }
  }

  @override
  void onTimeout(ChallengeHost host) =>
      host.fail(reason: params.tr('common.too_slow'));

  static WaitForGreenChallenge build(ChallengeParams p) {
    final greenAt = Duration(milliseconds: 900 + p.rng.nextInt(1400));
    final window = Duration(
      milliseconds: max(420, (750 / p.speed).round()),
    );
    return WaitForGreenChallenge(p, greenAt, window);
  }
}

/// 22 — TAP AFTER EXACTLY 2 SECONDS. No countdown. Shows your error.
class PreciseTimingChallenge extends BaseChallenge {
  PreciseTimingChallenge(ChallengeParams p, this.targetTime, this.tolerance)
      : super(
          p,
          id: 'precise_timing',
          tag: ChallengeTag.reaction,
          duration: targetTime + tolerance + const Duration(milliseconds: 260),
        ) {
    final secs = (targetTime.inMilliseconds / 1000).toStringAsFixed(0);
    instruction = p.tr('challenge.precise_timing.instruction', {'secs': secs});
    layout = ChallengeLayout.none;
    showTimer = false;
  }

  final Duration targetTime;
  final Duration tolerance;

  @override
  void onTap(TapInfo tap, ChallengeHost host) {
    if (tap.kind != TapKind.down) return;
    final diff = tap.elapsed - targetTime;
    final label = _format(diff);
    if (diff.abs() <= tolerance) {
      host.pass(note: label);
    } else {
      host.fail(
        reason: params.tr('challenge.precise_timing.off', {'label': label}),
      );
    }
  }

  @override
  void onTimeout(ChallengeHost host) =>
      host.fail(reason: params.tr('challenge.precise_timing.late'));

  static String _format(Duration d) {
    final sign = d.isNegative ? '-' : '+';
    final s = (d.inMilliseconds.abs() / 1000).toStringAsFixed(2);
    return '$sign${s}s';
  }

  static PreciseTimingChallenge build(ChallengeParams p) {
    final seconds = 2 + p.rng.nextInt(2); // 2..3
    final tol = Duration(
      milliseconds: max(200, (460 / p.speed).round()),
    );
    return PreciseTimingChallenge(p, Duration(seconds: seconds), tol);
  }
}

/// 23 — HOLD THE BUTTON. Letting go is a fail. So is never pressing.
class HoldButtonChallenge extends BaseChallenge {
  HoldButtonChallenge(ChallengeParams p)
      : super(
          p,
          id: 'hold_button',
          tag: ChallengeTag.patience,
          duration: p.pace(const Duration(milliseconds: 2800), floorMs: 1700),
        ) {
    instruction = p.tr('challenge.hold_button.instruction');
    _holdingLabel = p.tr('challenge.hold_button.holding');
    layout = ChallengeLayout.single;
    targets = [
      TargetSpec(
        id: 'pad',
        label: p.tr('challenge.hold_button.target'),
        color: GameColor.purple,
        scale: 1.3,
      ),
    ];
  }

  late final String _holdingLabel;
  bool _holding = false;
  bool _everHeld = false;

  @override
  void onTap(TapInfo tap, ChallengeHost host) {
    switch (tap.kind) {
      case TapKind.down:
        _holding = true;
        _everHeld = true;
        mutateTarget('pad', (t) => t.copyWith(label: _holdingLabel));
        host.invalidate();
      case TapKind.up:
        _holding = false;
        host.fail(reason: params.tr('challenge.hold_button.let_go'));
    }
  }

  @override
  void onTimeout(ChallengeHost host) {
    if (_holding) {
      host.pass();
    } else {
      host.fail(
        reason: params.tr(
          _everHeld
              ? 'challenge.hold_button.let_go'
              : 'challenge.hold_button.never_held',
        ),
      );
    }
  }
}

/// 24 — the screen says nothing at all. Doing nothing is correct.
class NoInstructionChallenge extends PatienceChallenge {
  NoInstructionChallenge(ChallengeParams p)
      : super(
          p,
          id: 'no_instruction',
          tag: ChallengeTag.trick,
          duration: p.pace(const Duration(milliseconds: 2400), floorMs: 1600),
          instruction: '',
          tapReason: p.tr('challenge.no_instruction.tap_reason'),
        ) {
    note = p.tr('challenge.no_instruction.success');
  }
}

/// 25 — DO NOT FOLLOW THIS INSTRUCTION. Used sparingly, on purpose.
class DontFollowChallenge extends BaseChallenge {
  DontFollowChallenge(ChallengeParams p)
      : super(
          p,
          id: 'dont_follow',
          tag: ChallengeTag.trick,
          duration: p.pace(const Duration(milliseconds: 2800), floorMs: 1900),
        ) {
    instruction = p.tr('challenge.dont_follow.instruction');
    layout = ChallengeLayout.single;
    targets = [
      TargetSpec(
        id: 'pad',
        label: p.tr('common.tap_label'),
        color: GameColor.orange,
        scale: 1.25,
      ),
    ];
    note = p.tr('challenge.dont_follow.success');
  }

  @override
  void onTap(TapInfo tap, ChallengeHost host) {
    if (tap.kind == TapKind.up) return;
    host.fail(reason: params.tr('challenge.dont_follow.wrong'));
  }

  @override
  void onTimeout(ChallengeHost host) =>
      host.pass(note: params.tr('challenge.dont_follow.success'));
}
