/// What the host knows about a hardware round ([[Unfold Your Brain]] → Host).
///
/// Watches one round's normalized [FoldableEvent]s and taps, then answers
/// the questions the presenter jokes about: what was expected, what the
/// player actually did, how long it took, whether they kept flapping the
/// hinge. Two consumers, both existing:
///
/// - the **scripted aside** on the wrong flash ([scriptedAside]) — the
///   challenge's own fail line stays the headline;
/// - the **AI Game Over verdict** — [FoldableRoundSummary.toContext] is
///   merged into [RunSummary] facts for the on-device model, through the
///   same validated, fallback-first [CommentaryProvider] as every other line.
///
/// No new AI service, no await on the hot path. PURE DART.
library;

import 'dart:math';

import '../challenges/foldable_challenges.dart';
import '../core/challenge.dart';
import '../core/foldable.dart';
import '../i18n/app_locale.dart';
import '../i18n/strings.dart';

class FoldableRoundSummary {
  const FoldableRoundSummary({
    required this.challengeId,
    required this.expected,
    required this.passed,
    required this.elapsed,
    required this.opens,
    required this.closes,
    required this.angleMoves,
    required this.displaySwitches,
    required this.taps,
    required this.hardwareFailsThisRun,
  });

  final String challengeId;

  /// Null for a classic (non-hardware) challenge.
  final ExpectedInteraction? expected;
  final bool passed;
  final Duration elapsed;
  final int opens;
  final int closes;
  final int angleMoves;
  final int displaySwitches;
  final int taps;

  /// Hardware rounds failed so far in this run, this one included.
  final int hardwareFailsThisRun;

  bool get isHardwareRound => expected != null;
  int get hingeActions => opens + closes + angleMoves;
  bool get physical => hingeActions + displaySwitches > 0;

  /// Open/close over and over.
  bool get flapping => opens + closes >= 4;

  /// What the player mostly tried: `fold`, `display`, `tap`, `nothing`.
  String get attempted {
    if (!physical && taps == 0) return 'nothing';
    if (taps > 0 && !physical) return 'tap';
    if (displaySwitches > hingeActions) return 'display';
    return 'fold';
  }

  /// The aside pool that fits, most specific first. Null = nothing notable.
  String? get asidePool {
    if (passed) return null;
    if (flapping) return 'fold.host.flapping';
    if (!isHardwareRound) {
      if (!physical) return null;
      return taps > 0 ? 'fold.host.folded_instead' : 'fold.host.needless_fold';
    }
    if (attempted == 'tap') return 'fold.host.tapped_instead';
    return 'fold.host.smarter';
  }

  /// Facts for the AI verdict. Player-facing game facts only
  /// ([[Privacy and Offline]]).
  Map<String, Object?> toContext() => {
    'hardwareChallenge': isHardwareRound ? 'yes' : 'no',
    if (expected != null) 'expectedPhysicalAction': _describe(expected!),
    'playerTried': attempted,
    'secondsTaken': (elapsed.inMilliseconds / 1000).toStringAsFixed(1),
    if (opens + closes > 0) 'timesOpenedOrClosed': opens + closes,
    if (flapping) 'keptOpeningAndClosing': 'yes',
    if (hardwareFailsThisRun > 1) 'hardwareFailsThisRun': hardwareFailsThisRun,
  };

  static String _describe(ExpectedInteraction e) => switch (e) {
    ExpectedInteraction.partialFold => 'fold the phone halfway',
    ExpectedInteraction.stayClosed => 'keep the phone closed and do nothing',
    ExpectedInteraction.hingeAngle => 'hold the hinge at a secret angle',
    ExpectedInteraction.displaySwitch => 'switch to the other screen',
    ExpectedInteraction.halfOpenThenTap => 'half-open the phone, then tap',
  };
}

/// One per game screen. Feed it every event and tap; ask at the end.
class FoldableRoundTracker {
  String _id = '';
  ExpectedInteraction? _expected;
  int _opens = 0, _closes = 0, _angle = 0, _display = 0, _taps = 0;
  int _hardwareFails = 0;

  void resetRun() => _hardwareFails = 0;

  void startRound(Challenge challenge) {
    _id = challenge.id;
    _expected = challenge is FoldableChallenge ? challenge.expected : null;
    _opens = _closes = _angle = _display = _taps = 0;
  }

  void recordEvent(FoldableEvent e) {
    switch (e.kind) {
      case FoldableEventKind.deviceOpened:
        _opens++;
      case FoldableEventKind.deviceClosed:
        _closes++;
      case FoldableEventKind.hingeAngleChanged:
        _angle++;
      case FoldableEventKind.displayConfigurationChanged:
        _display++;
      case FoldableEventKind.initialState:
      case FoldableEventKind.deviceOrientationChanged:
      case FoldableEventKind.hingeUnavailable:
        break;
    }
  }

  void recordTap() => _taps++;

  FoldableRoundSummary finish({
    required bool passed,
    required Duration elapsed,
  }) {
    if (!passed && _expected != null) _hardwareFails++;
    return FoldableRoundSummary(
      challengeId: _id,
      expected: _expected,
      passed: passed,
      elapsed: elapsed,
      opens: _opens,
      closes: _closes,
      angleMoves: _angle,
      displaySwitches: _display,
      taps: _taps,
      hardwareFailsThisRun: _hardwareFails,
    );
  }
}

/// Pool sizes, kept next to the keys in the string tables.
const _poolSizes = {
  'fold.host.needless_fold': 3,
  'fold.host.flapping': 3,
  'fold.host.smarter': 3,
  'fold.host.tapped_instead': 2,
  'fold.host.folded_instead': 2,
};

/// A scripted host aside for [summary], or null when nothing about the
/// round is worth a hardware joke.
String? scriptedAside(
  FoldableRoundSummary summary,
  AppLocale locale,
  Random rng,
) {
  final pool = summary.asidePool;
  if (pool == null) return null;
  final n = _poolSizes[pool]!;
  return Strings.t(locale, '$pool.${rng.nextInt(n)}');
}
