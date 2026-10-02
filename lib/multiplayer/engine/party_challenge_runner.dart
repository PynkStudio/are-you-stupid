/// Drives one round's [Challenge] on the client — the same pure-Dart engine
/// single-player uses (`onStart`/`onTick`/`onTap`/`onTimeout`) — and reports
/// the resulting verdict instead of only showing it locally. See the
/// design-change note on `PlayerAction` in `../protocol/protocol.dart` for
/// why judging moved from the host to here.
///
/// Deliberately minimal next to `core/game_engine.dart`: no levels, no
/// run/continue state, no roasts — just "run this one Challenge to a
/// decision, once." Pure Dart: no Flutter imports, no owned `Timer`
/// ([[Multiplayer Client (Mobile)]]) — [tick] is driven externally, exactly
/// like `GameEngine.tick(delta)` is driven by `game_screen.dart`'s own
/// `Ticker`. That keeps this class trivially headless-testable (a test just
/// calls [tick] directly, synchronously, instead of waiting on real time —
/// mirrors `FakePartyClock`'s role on the host side) while production
/// drives it from a real per-frame `Ticker`.
library;

import '../../core/challenge.dart';

/// One challenge's outcome, as computed locally.
class PartyVerdict {
  const PartyVerdict({required this.correct, this.reason, this.note});

  final bool correct;

  /// One-line wrong-answer explanation — every template ships one
  /// (docs/Gameplay/Game Design Pillars.md).
  final String? reason;

  /// Optional correct-answer flourish (e.g. a reaction-time note).
  final String? note;
}

/// Drives exactly one [Challenge] instance through its lifecycle for one
/// multiplayer round. Calls `Challenge.onStart` immediately (construction
/// time), then [tick] (called repeatedly with the elapsed time since GO) and
/// [tap] feed it input until [onVerdict] fires — exactly once, tap-triggered
/// or timeout-triggered.
class PartyChallengeRunner implements ChallengeHost {
  PartyChallengeRunner(
    this.challenge, {
    this.onInvalidate,
    required this.onVerdict,
  }) {
    challenge.onStart(this);
  }

  final Challenge challenge;

  /// Called whenever the challenge's view changes on its own (a
  /// timer-driven trap moved, a memory blackout lifted, …) so the UI can
  /// repaint without waiting for the next external event. Also fires for a
  /// challenge that decides its own outcome inside `onStart`, before the
  /// first [tick] — vanishingly rare, but not disallowed by the `Challenge`
  /// contract.
  final void Function()? onInvalidate;

  /// Fires exactly once, the moment the challenge settles.
  final void Function(PartyVerdict verdict) onVerdict;

  bool _settled = false;
  Duration _elapsed = Duration.zero;

  /// Elapsed time as of the last [tick]/[tap] — public so the UI can stamp
  /// a `TapInfo` without keeping a second clock.
  Duration get elapsed => _elapsed;

  bool get settled => _settled;

  /// Advances the challenge to absolute time [elapsed] since GO. A no-op
  /// once settled. Firing `onTimeout` is this method's job, not [tap]'s —
  /// matches `Challenge.duration`'s contract ("when it expires, onTimeout
  /// fires").
  void tick(Duration elapsed) {
    if (_settled) return;
    _elapsed = elapsed;
    if (elapsed >= challenge.duration) {
      challenge.onTimeout(this);
      return;
    }
    challenge.onTick(elapsed, this);
  }

  /// Forwards one tap. Ignored once the challenge has already settled.
  void tap(TapInfo info) {
    if (_settled) return;
    _elapsed = info.elapsed;
    challenge.onTap(info, this);
  }

  @override
  void pass({String? note}) => _settle(PartyVerdict(correct: true, note: note));

  @override
  void fail({String? reason}) =>
      _settle(PartyVerdict(correct: false, reason: reason));

  @override
  void invalidate() => onInvalidate?.call();

  void _settle(PartyVerdict verdict) {
    if (_settled) return;
    _settled = true;
    onVerdict(verdict);
  }
}
