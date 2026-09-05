import 'dart:math';

import '../core/challenge.dart';
import 'base.dart';

/// Shared skeleton: SHOW something → hide it → ASK about it.
abstract class _ShowThenAskChallenge extends BaseChallenge {
  _ShowThenAskChallenge(
    ChallengeParams p, {
    required String id,
    required this.showFor,
    required this.blankFor,
    required Duration answerWindow,
  }) : super(
          p,
          id: id,
          tag: ChallengeTag.memory,
          duration: showFor + blankFor + answerWindow,
        );

  final Duration showFor;
  final Duration blankFor;

  int _phase = 0; // 0 show, 1 blank, 2 ask
  bool get answering => _phase == 2;

  void showPhase();
  void askPhase();

  @override
  void onStart(ChallengeHost host) => showPhase();

  @override
  void onTick(Duration elapsed, ChallengeHost host) {
    if (_phase == 0 && elapsed >= showFor) {
      _phase = 1;
      blackout = true;
      instruction = '...';
      targets = const [];
      host.invalidate();
    } else if (_phase == 1 && elapsed >= showFor + blankFor) {
      _phase = 2;
      blackout = false;
      askPhase();
      host.invalidate();
    }
  }

  @override
  void onTimeout(ChallengeHost host) => host.fail(reason: 'GONE ALREADY?');
}

/// 26 — REMEMBER: BLUE.
class RememberColorChallenge extends _ShowThenAskChallenge {
  RememberColorChallenge(ChallengeParams p)
      : _secret = p.pick(kBasicColors),
        _options = p.shuffled(kBasicColors),
        super(
          p,
          id: 'remember_color',
          showFor: const Duration(milliseconds: 900),
          blankFor: const Duration(milliseconds: 420),
          answerWindow: p.pace(const Duration(milliseconds: 2400), floorMs: 1200),
        );

  final GameColor _secret;
  final List<GameColor> _options;

  @override
  void showPhase() {
    instruction = 'REMEMBER';
    layout = ChallengeLayout.single;
    showTimer = false;
    targets = [
      TargetSpec(id: 'show', label: '', color: _secret, scale: 1.35),
    ];
  }

  @override
  void askPhase() {
    instruction = 'TAP THE COLOR';
    layout = ChallengeLayout.grid2x2;
    showTimer = true;
    targets = [
      for (var i = 0; i < _options.length; i++)
        TargetSpec(id: 'c$i', color: _options[i]),
    ];
  }

  @override
  void onTap(TapInfo tap, ChallengeHost host) {
    if (!answering || tap.kind != TapKind.down || tap.isBackground) return;
    final hit = targets.firstWhere((t) => t.id == tap.targetId);
    if (hit.color == _secret) {
      host.pass();
    } else {
      host.fail(reason: 'IT WAS ${_secret.label}.');
    }
  }
}

/// 27 — REMEMBER: 7.
class RememberNumberChallenge extends _ShowThenAskChallenge {
  RememberNumberChallenge(ChallengeParams p)
      : _secret = 10 + p.rng.nextInt(89),
        super(
          p,
          id: 'remember_number',
          showFor: const Duration(milliseconds: 950),
          blankFor: const Duration(milliseconds: 450),
          answerWindow: p.pace(const Duration(milliseconds: 2600), floorMs: 1300),
        ) {
    final options = <int>{_secret};
    while (options.length < 4) {
      final noise = _secret + (p.rng.nextInt(21) - 10);
      if (noise > 9 && noise < 100) options.add(noise);
    }
    _options = p.shuffled(options.toList());
  }

  final int _secret;
  late final List<int> _options;

  @override
  void showPhase() {
    instruction = 'REMEMBER';
    layout = ChallengeLayout.none;
    showTimer = false;
    bigCenterText = '$_secret';
  }

  @override
  void askPhase() {
    instruction = 'TAP THE NUMBER';
    bigCenterText = null;
    layout = ChallengeLayout.grid2x2;
    showTimer = true;
    targets = numberTargets(_options);
  }

  @override
  void onTap(TapInfo tap, ChallengeHost host) {
    if (!answering || tap.kind != TapKind.down || tap.isBackground) return;
    if (tap.targetId == 'n$_secret') {
      host.pass();
    } else {
      host.fail(reason: 'IT WAS $_secret.');
    }
  }
}

/// 28 — a burst of colors. Only the last one matters.
class LastColorChallenge extends BaseChallenge {
  LastColorChallenge(ChallengeParams p, this._sequence, Duration answerWindow)
      : super(
          p,
          id: 'last_color',
          tag: ChallengeTag.memory,
          duration: Duration(milliseconds: _sequence.length * _stepMs) +
              answerWindow,
        ) {
    instruction = 'WATCH';
    layout = ChallengeLayout.single;
    showTimer = false;
    targets = [TargetSpec(id: 'show', color: _sequence.first, scale: 1.35)];
  }

  static const _stepMs = 420;

  final List<GameColor> _sequence;
  int _index = 0;
  bool _asking = false;
  late final List<GameColor> _options = params.shuffled(kBasicColors);

  @override
  void onTick(Duration elapsed, ChallengeHost host) {
    if (_asking) return;
    final step = elapsed.inMilliseconds ~/ _stepMs;
    if (step >= _sequence.length) {
      _asking = true;
      instruction = 'TAP THE LAST COLOR';
      layout = ChallengeLayout.grid2x2;
      showTimer = true;
      targets = [
        for (var i = 0; i < _options.length; i++)
          TargetSpec(id: 'c$i', color: _options[i]),
      ];
      host.invalidate();
      return;
    }
    if (step != _index) {
      _index = step;
      targets = [
        TargetSpec(id: 'show', color: _sequence[_index], scale: 1.35),
      ];
      host.invalidate();
    }
  }

  @override
  void onTap(TapInfo tap, ChallengeHost host) {
    if (!_asking || tap.kind != TapKind.down || tap.isBackground) return;
    final hit = targets.firstWhere((t) => t.id == tap.targetId);
    if (hit.color == _sequence.last) {
      host.pass();
    } else {
      host.fail(reason: 'THE LAST ONE.');
    }
  }

  @override
  void onTimeout(ChallengeHost host) => host.fail(reason: 'GONE ALREADY?');

  static LastColorChallenge build(ChallengeParams p) {
    final len = 3 + min(2, p.level ~/ 12);
    final seq = <GameColor>[];
    while (seq.length < len) {
      final c = p.pick(kBasicColors);
      if (seq.isEmpty || seq.last != c) seq.add(c);
    }
    return LastColorChallenge(
      p,
      seq,
      p.pace(const Duration(milliseconds: 2400), floorMs: 1200),
    );
  }
}

/// 29 — one button lights up. Then they all look the same again.
class RememberPositionChallenge extends _ShowThenAskChallenge {
  RememberPositionChallenge(ChallengeParams p)
      : _lit = p.rng.nextInt(4),
        super(
          p,
          id: 'remember_position',
          showFor: const Duration(milliseconds: 850),
          blankFor: const Duration(milliseconds: 400),
          answerWindow: p.pace(const Duration(milliseconds: 2400), floorMs: 1200),
        );

  final int _lit;

  @override
  void showPhase() {
    instruction = 'WATCH';
    layout = ChallengeLayout.grid2x2;
    showTimer = false;
    targets = [
      for (var i = 0; i < 4; i++)
        TargetSpec(
          id: 'p$i',
          color: i == _lit ? GameColor.yellow : GameColor.slate,
        ),
    ];
  }

  @override
  void askPhase() {
    instruction = 'WHICH ONE LIT UP?';
    showTimer = true;
    targets = [
      for (var i = 0; i < 4; i++) TargetSpec(id: 'p$i', color: GameColor.slate),
    ];
  }

  @override
  void onTap(TapInfo tap, ChallengeHost host) {
    if (!answering || tap.kind != TapKind.down || tap.isBackground) return;
    if (tap.targetId == 'p$_lit') {
      host.pass();
    } else {
      host.fail(reason: 'WRONG CORNER.');
    }
  }
}
