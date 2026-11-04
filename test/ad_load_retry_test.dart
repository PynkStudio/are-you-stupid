import 'dart:async';

import 'package:are_you_stupid/services/ads/ad_load_retry.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeTimer implements Timer {
  _FakeTimer(this.delay, this.callback);

  final Duration delay;
  final void Function() callback;
  bool cancelled = false;

  @override
  void cancel() => cancelled = true;

  @override
  bool get isActive => !cancelled;

  @override
  int get tick => 0;
}

void main() {
  late List<_FakeTimer> timers;
  late int loads;
  late AdLoadRetry retry;

  setUp(() {
    timers = [];
    loads = 0;
    retry = AdLoadRetry(
      () => loads++,
      schedule: (delay, callback) {
        final timer = _FakeTimer(delay, callback);
        timers.add(timer);
        return timer;
      },
    );
  });

  test('backs off from 30 s and doubles up to the 5 minute cap', () {
    for (var i = 0; i < 6; i++) {
      retry.failed();
    }
    expect(timers.map((t) => t.delay.inSeconds), [30, 60, 120, 240, 300, 300]);
  });

  test('the scheduled retry runs the load', () {
    retry.failed();
    expect(loads, 0);
    timers.single.callback();
    expect(loads, 1);
  });

  test('a new failure replaces the pending retry', () {
    retry.failed();
    retry.failed();
    expect(timers.first.cancelled, isTrue);
    expect(timers.last.cancelled, isFalse);
  });

  test('success cancels the pending retry and resets the backoff', () {
    retry.failed();
    retry.failed();
    retry.succeeded();
    expect(timers.last.cancelled, isTrue);
    expect(retry.nextDelay, const Duration(seconds: 30));
  });
}
