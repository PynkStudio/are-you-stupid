import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:are_you_stupid/ai/prefetch_loop.dart';

void main() {
  group('PrefetchLoop', () {
    test('popNext is a miss (null) on an empty ring', () {
      final loop = PrefetchLoop<int>(fetch: () async => 1);
      expect(loop.popNext(), isNull);
    });

    test('maybeStart fills the ring, popNext drains it (single-read pop)', () async {
      var calls = 0;
      final loop = PrefetchLoop<int>(fetch: () async {
        calls++;
        return calls;
      });

      loop.maybeStart();
      await Future<void>.delayed(Duration.zero);
      expect(loop.popNext(), 1);
      expect(loop.popNext(), isNull); // popped once, not re-servable
    });

    test('does not start a second fetch while one is already in flight', () async {
      var inFlight = 0;
      var maxConcurrent = 0;
      final completer = Completer<int?>();
      final loop = PrefetchLoop<int>(
        fetch: () {
          inFlight++;
          maxConcurrent = inFlight > maxConcurrent ? inFlight : maxConcurrent;
          return completer.future.whenComplete(() => inFlight--);
        },
      );

      loop.maybeStart();
      loop.maybeStart(); // no-op: already fetching
      loop.maybeStart();
      completer.complete(1);
      await Future<void>.delayed(Duration.zero);

      expect(maxConcurrent, 1);
    });

    test('does not start a new fetch once the ring is full', () async {
      var calls = 0;
      final loop = PrefetchLoop<int>(fetch: () async {
        calls++;
        return calls;
      }, ringSize: 1);

      loop.maybeStart();
      await Future<void>.delayed(Duration.zero);
      expect(loop.isFull, isTrue);

      loop.maybeStart(); // ring already full — no-op
      await Future<void>.delayed(Duration.zero);
      expect(calls, 1);
    });

    test('a null fetch result leaves the ring empty and retryable', () async {
      var calls = 0;
      final loop = PrefetchLoop<int>(fetch: () async {
        calls++;
        return calls == 1 ? null : 42;
      });

      loop.maybeStart();
      await Future<void>.delayed(Duration.zero);
      expect(loop.popNext(), isNull);

      loop.maybeStart();
      await Future<void>.delayed(Duration.zero);
      expect(loop.popNext(), 42);
    });

    test('a thrown fetch error is swallowed, not propagated', () async {
      final loop = PrefetchLoop<int>(fetch: () async => throw StateError('boom'));
      loop.maybeStart();
      await Future<void>.delayed(Duration.zero);
      expect(loop.popNext(), isNull); // no crash, just a miss
    });

    test('invalidate clears the ring and discards a result already in flight', () async {
      final completer = Completer<int?>();
      final loop = PrefetchLoop<int>(fetch: () => completer.future);

      loop.maybeStart();
      loop.invalidate(); // the in-flight fetch below is now stale
      completer.complete(99);
      await Future<void>.delayed(Duration.zero);

      expect(loop.popNext(), isNull); // discarded, not stored
    });

    test('invalidate lets a fresh fetch start immediately, not waiting on the stale one', () async {
      final staleCompleter = Completer<int?>();
      var freshFetchStarted = false;
      var useStale = true;
      final loop = PrefetchLoop<int>(
        fetch: () {
          if (useStale) return staleCompleter.future;
          freshFetchStarted = true;
          return Future.value(2);
        },
      );

      loop.maybeStart(); // starts the "stale" fetch (never resolves yet)
      loop.invalidate();
      useStale = false;
      loop.maybeStart(); // should start immediately, not wait on staleCompleter

      expect(freshFetchStarted, isTrue);
      staleCompleter.complete(1); // clean up the still-pending stale future
    });

    test('respects a custom ringSize', () async {
      var calls = 0;
      final loop = PrefetchLoop<int>(fetch: () async {
        calls++;
        return calls;
      }, ringSize: 2);

      loop.maybeStart();
      await Future<void>.delayed(Duration.zero);
      loop.maybeStart();
      await Future<void>.delayed(Duration.zero);
      expect(loop.isFull, isTrue);

      loop.maybeStart(); // full — no third fetch
      await Future<void>.delayed(Duration.zero);
      expect(calls, 2);
    });
  });
}
