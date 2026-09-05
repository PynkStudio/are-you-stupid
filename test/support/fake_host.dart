import 'package:are_you_stupid/core/challenge.dart';

/// Collects what a challenge decided, so every template can be driven headless.
class FakeHost implements ChallengeHost {
  bool passed = false;
  bool failed = false;
  String? note;
  String? reason;
  int invalidations = 0;

  bool get settled => passed || failed;

  @override
  void pass({String? note}) {
    if (settled) return;
    passed = true;
    this.note = note;
  }

  @override
  void fail({String? reason}) {
    if (settled) return;
    failed = true;
    this.reason = reason;
  }

  @override
  void invalidate() => invalidations++;
}

/// Runs a challenge forward without a Ticker.
void advance(
  Challenge challenge,
  FakeHost host, {
  required Duration to,
  Duration step = const Duration(milliseconds: 16),
}) {
  var t = Duration.zero;
  while (t < to && !host.settled) {
    t += step;
    challenge.onTick(t, host);
  }
  if (!host.settled && to >= challenge.duration) {
    challenge.onTimeout(host);
  }
}

TapInfo tapOn(String id, {int index = 0, Duration at = Duration.zero}) =>
    TapInfo(targetId: id, index: index, elapsed: at);

TapInfo tapBackground({Duration at = Duration.zero}) =>
    TapInfo(targetId: null, elapsed: at);
