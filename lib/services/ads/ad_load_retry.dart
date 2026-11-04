import 'dart:async';

/// Retries a failed ad load with exponential backoff.
///
/// Without this, one failed load (offline at launch, no fill) left the
/// placement empty until the next app launch, because nothing else asks for
/// a load while `isReady` is false. See docs/Product/Monetization and Ads.md.
class AdLoadRetry {
  AdLoadRetry(
    this._load, {
    this.baseDelay = const Duration(seconds: 30),
    this.maxDelay = const Duration(minutes: 5),
    Timer Function(Duration, void Function()) schedule = Timer.new,
  }) : _schedule = schedule;

  final void Function() _load;
  final Duration baseDelay;
  final Duration maxDelay;
  final Timer Function(Duration, void Function()) _schedule;

  int _failures = 0;
  Timer? _timer;

  /// The wait before the next retry, given the failures so far.
  Duration get nextDelay {
    var delay = baseDelay;
    for (var i = 0; i < _failures && delay < maxDelay; i++) {
      delay *= 2;
    }
    return delay > maxDelay ? maxDelay : delay;
  }

  /// Schedules one retry. A retry already pending is replaced, so failures
  /// can never stack up into parallel timers.
  void failed() {
    _timer?.cancel();
    _timer = _schedule(nextDelay, _load);
    _failures++;
  }

  /// A load worked: drop any pending retry and start over from [baseDelay].
  void succeeded() {
    _timer?.cancel();
    _timer = null;
    _failures = 0;
  }
}
