/// Pre-generation cache primitive ([[Pre-generation Cache]], Phase 5 of the
/// AI Director plan): a small bounded ring, filled by a background async
/// fetch, popped synchronously — the shape that lets the game loop never
/// await a model ([[Performance and Resource Budgets]]).
///
/// This file is generic over the cached item type on purpose: it backs both
/// the challenge ring (`AIChallengeProvider`, size 2) and one commentary
/// ring per kind (`CommentaryCache`, size 1 each) with the same primitive,
/// matching [[Pre-generation Cache]]'s "buffer rings" section.
///
/// This file is PURE DART: no Flutter imports.
library;

/// One bounded ring + a single-in-flight background fetch.
///
/// Contract ([[Pre-generation Cache]]):
/// - **Every read is a pop.** [popNext] removes the item — no stale reroll
///   is ever served twice.
/// - **At most one fetch in flight at a time.** [maybeStart] is a no-op
///   while a fetch is already running or the ring is already full.
/// - **A fetch that resolves after [invalidate] is discarded**, not stored
///   — the generation counter below is the same idea as the design doc's
///   `cancelUnit`, minus needing a real cancellable `Future` (Dart futures
///   aren't cancellable; discarding a stale result on arrival is the
///   equivalent, matching the doc's own "Swift single-await generation
///   either completes (validation discards it) or is ignored").
/// - **[invalidate] doesn't block a new fetch on the old one finishing** —
///   it resets the in-flight flag immediately, so a key change (locale/
///   level-band change) can start fetching the new key right away rather
///   than waiting out a fetch for a key nobody wants anymore. This can
///   transiently run two generations at once (the stale one about to be
///   discarded, the fresh one just started) — a deliberate, brief exception
///   to the single-in-flight rule, not a bug.
class PrefetchLoop<T> {
  PrefetchLoop({required Future<T?> Function() fetch, this.ringSize = 2})
      : _fetch = fetch;

  final Future<T?> Function() _fetch;
  final int ringSize;

  final List<T> _ring = [];
  bool _fetching = false;
  int _generation = 0;

  bool get isFull => _ring.length >= ringSize;
  bool get isEmpty => _ring.isEmpty;

  /// Removes and returns the oldest ready item, or `null` on a cache miss —
  /// callers treat `null` exactly like [[AI Challenge Generation]]'s
  /// `ChallengeProvider.next()` contract: "nothing to offer right now."
  T? popNext() => _ring.isEmpty ? null : _ring.removeAt(0);

  /// Fire-and-forget: kicks a background fetch if the ring isn't full and
  /// nothing is already in flight. Never throws, never awaited by the
  /// caller — a failed or `null` fetch just leaves the ring exactly as it
  /// was, and the next [maybeStart] tries again.
  void maybeStart() {
    if (_fetching || isFull) return;
    _fetching = true;
    final startedAtGeneration = _generation;
    _fetch().then(
      (value) {
        _fetching = false;
        if (startedAtGeneration != _generation) return; // stale — discard.
        if (value != null && _ring.length < ringSize) {
          _ring.add(value);
        }
      },
      onError: (Object error, StackTrace stack) {
        _fetching = false;
      },
    );
  }

  /// Drops everything cached and marks any in-flight fetch as stale — call
  /// when the derived cache key changes (locale / level-band / allowTricks).
  void invalidate() {
    _generation++;
    _ring.clear();
    _fetching = false;
  }
}
