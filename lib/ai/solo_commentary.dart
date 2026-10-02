/// Single-player live commentary ([[AI Commentary]] → Where the lines land):
/// the piece that makes [CommentaryProvider] actually reach a solo player
/// without the game loop ever awaiting a model
/// ([[Performance and Resource Budgets]]).
///
/// Two moments, two strategies:
///
/// - **Wrong flash aside** — prefetched. A size-1 [PrefetchLoop] keeps one
///   `wrong` line ready from the first level on; the fail flash pops it
///   synchronously. Empty ring → no aside, the flash looks exactly like the
///   scripted game. The challenge's own fail line always stays the headline
///   ([[Game Design Pillars]] → every failure explainable in one line).
/// - **Game Over verdict** — requested at the moment of the fail, with the
///   run's real facts. The 2.85 s wrong flash is its latency budget; a late
///   or failed verdict just means the static roast stays.
///
/// This file is PURE DART: no Flutter imports.
library;

import '../i18n/app_locale.dart';
import 'commentary.dart';
import 'prefetch_loop.dart';

/// The facts of a finished run the verdict is written from. Player-facing
/// game text only — no name, no history, no profile
/// ([[Privacy and Offline]]).
class RunSummary {
  const RunSummary({
    required this.level,
    required this.best,
    required this.newBest,
    required this.bestStreak,
    this.failedInstruction,
    this.failReason,
  });

  final int level;

  /// Personal best *before* this run.
  final int best;
  final bool newBest;
  final int bestStreak;

  /// The instruction on screen when the run ended.
  final String? failedInstruction;

  /// The challenge's own one-line explanation of the failure.
  final String? failReason;

  Map<String, Object?> toContext() => {
        'levelReached': level,
        'personalBest': best,
        'newPersonalBest': newBest ? 'yes' : 'no',
        'bestFastStreak': bestStreak,
        if (failedInstruction != null) 'failedInstruction': failedInstruction,
        if (failReason != null) 'whyTheyFailed': failReason,
      };
}

class SoloCommentator {
  SoloCommentator({required CommentaryProvider provider})
      : _provider = provider {
    _wrongRing = PrefetchLoop<String>(fetch: _fetchWrong, ringSize: 1);
  }

  final CommentaryProvider _provider;
  late final PrefetchLoop<String> _wrongRing;

  AppLocale _locale = AppLocale.en;
  bool _allowSpicy = true;
  int _level = 1;

  Future<String?> _fetchWrong() => _provider.aiLine(
        kind: CommentaryKind.wrong,
        locale: _locale,
        allowSpicy: _allowSpicy,
        context: {'level': _level},
      );

  /// Call on every level start: keeps one `wrong` aside ready. A locale or
  /// spicy-roasts change drops the cached line (it was written for the old
  /// setting) and starts over.
  void warm({
    required AppLocale locale,
    required bool allowSpicy,
    required int level,
  }) {
    if (locale != _locale || allowSpicy != _allowSpicy) {
      _wrongRing.invalidate();
    }
    _locale = locale;
    _allowSpicy = allowSpicy;
    _level = level;
    _wrongRing.maybeStart();
  }

  /// The ready aside for the wrong flash, or `null` (cache miss → no aside).
  /// Every read is a pop: a line is never shown twice.
  String? takeWrongAside() => _wrongRing.popNext();

  /// The Game Over headline written from [run], or `null` when the model
  /// has nothing valid to offer (the caller keeps its static roast).
  Future<String?> verdict({
    required AppLocale locale,
    required bool allowSpicy,
    required RunSummary run,
  }) =>
      _provider.aiLine(
        kind: CommentaryKind.gameOver,
        locale: locale,
        allowSpicy: allowSpicy,
        context: run.toContext(),
      );
}
