/// Player telemetry + adaptive profile: the Director's eyes
/// ([[Player Telemetry and Adaptive Difficulty]], Phase 3).
///
/// This is the `lib/ai/` persistence layer ([[State and Persistence]] →
/// `ayu.*` is touched only by `lib/ai/`). It listens to the [GameEngine]
/// event boundary and derives a bounded rolling profile owned by the player's
/// device — no identity, no analytics, nothing leaves the phone
/// ([[Privacy and Offline]]). `lib/core/` stays ignorant of telemetry.
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/challenge.dart';
import '../core/game_engine.dart';
import '../core/game_state.dart';

/// SharedPreferences key for the persisted rolling profile
/// ([[State and Persistence]] → `ayu.profile`).
const String kProfileKey = 'ayu.profile';

/// Rolling window size for the windowed rates, per spec.
const int kProfileWindow = 50;

/// EMA smoothing factor used when the window underflows, per spec (α ≈ 0.15).
const double kEmaAlpha = 0.15;

/// Every failure is classified into at most one category (a nearest-match
/// against the *observable* signal, not a model judgment).
///
/// Categories that need per-tap detail (which decoy was hit, tap count) are
/// not derivable from the engine's event/snapshot boundary alone — those
/// resolve to `null` (no category) until a later phase exposes taps, exactly
/// as the spec allows: unknown/unclassifiable failures simply don't feed the
/// per-category weighting.
enum MistakeCategory {
  impulsiveTap,
  textColorConfusion,
  memoryFailure,
  countingFailure,
  timingFailure,
  instructionMisread,
  patternFailure,
  sequenceFailure,
  overthinking,
}

/// Parses a persisted [name] back to its enum; unknown names → null.
MistakeCategory? mistakeCategoryFromName(String? name) {
  for (final c in MistakeCategory.values) {
    if (c.name == name) return c;
  }
  return null;
}

/// A single observed round fed to the collector.
class RoundObserved {
  RoundObserved({
    required this.level,
    required this.mechanicId,
    this.sessionFastStreak = 0,
    this.reactionTimeMs,
    required this.timeLimitMs,
    required this.outcome,
    this.mistake,
  });

  /// The level the round was played at.
  final int level;

  /// The challenge/mechanic family id (the built `Challenge.id`).
  final String mechanicId;

  final int sessionFastStreak;

  /// Time to resolve, when known (ms).
  final int? reactionTimeMs;

  /// The round's configured time limit (ms).
  final int timeLimitMs;

  /// `correct` / `wrong` / `timeout`.
  final String outcome;

  /// Best-effort category for a failure; null when unclassifiable.
  final MistakeCategory? mistake;
}

/// The bounded, persisted, adaptive profile
/// ([[Player Telemetry and Adaptive Difficulty]] → "The profile").
///
/// `toJson`/`fromJson` round-trips the `ayu.profile` payload.
class PlayerGameplayProfile {
  PlayerGameplayProfile({
    this.totalRoundsPlayed = 0,
    this.fastestStreak = 0,
    this.successRateByMechanic = const {},
    this.mistakeRatesByCategory = const {},
    this.averageReactionTimeMs,
    this.reactionTimeVarianceMs,
    this.winRateByDifficulty = const {},
  });

  /// All-time counter (never windowed).
  final int totalRoundsPlayed;

  final int fastestStreak;

  /// Windowed success rate (0..1) per mechanic family.
  final Map<String, double> successRateByMechanic;

  /// Windowed share of failures falling in each category.
  final Map<String, double> mistakeRatesByCategory;

  /// EMA-composited reaction time (ms); null before any timed data.
  final double? averageReactionTimeMs;

  final double? reactionTimeVarianceMs;

  /// Windowed success rate by difficulty (level → rate).
  final Map<int, double> winRateByDifficulty;

  /// The single most common mistake category, or null when none is dominant.
  String? get mostCommonMistakeCategory {
    String? bestName;
    double best = 0;
    mistakeRatesByCategory.forEach((name, rate) {
      if (rate > best) {
        best = rate;
        bestName = name;
      }
    });
    return bestName;
  }

  bool get isEmpty => totalRoundsPlayed == 0;

  factory PlayerGameplayProfile.fromJson(Map<String, dynamic> json) =>
      PlayerGameplayProfile(
        totalRoundsPlayed: (json['totalRoundsPlayed'] as num?)?.toInt() ?? 0,
        fastestStreak: (json['fastestStreak'] as num?)?.toInt() ?? 0,
        successRateByMechanic: _stringDoubles(json['successRateByMechanic']),
        mistakeRatesByCategory: _stringDoubles(json['mistakeRatesByCategory']),
        averageReactionTimeMs:
            (json['averageReactionTimeMs'] as num?)?.toDouble(),
        reactionTimeVarianceMs:
            (json['reactionTimeVarianceMs'] as num?)?.toDouble(),
        winRateByDifficulty: _intDoubles(json['winRateByDifficulty']),
      );

  Map<String, dynamic> toJson() => {
        'totalRoundsPlayed': totalRoundsPlayed,
        'fastestStreak': fastestStreak,
        'successRateByMechanic': successRateByMechanic,
        'mistakeRatesByCategory': mistakeRatesByCategory,
        'mostCommonMistakeCategory': mostCommonMistakeCategory,
        'averageReactionTimeMs': averageReactionTimeMs,
        'reactionTimeVarianceMs': reactionTimeVarianceMs,
        'winRateByDifficulty': {
          for (final e in winRateByDifficulty.entries) '${e.key}': e.value,
        },
      };
}

Map<String, double> _stringDoubles(Object? value) => {
      for (final e in (value as Map?)?.entries ?? <MapEntry<dynamic, dynamic>>[])
        '${e.key}': (e.value as num).toDouble(),
    };

Map<int, double> _intDoubles(Object? value) => {
      for (final e in (value as Map?)?.entries ?? <MapEntry<dynamic, dynamic>>[])
        int.parse('${e.key}'): (e.value as num).toDouble(),
    };

/// Classifies a failure into at most one [MistakeCategory] from the
/// observable signals available at the event boundary.
///
/// Returns the best-fit category, or `null` when unclassifiable (the
/// per-tap-detail categories stay null until a later phase exposes taps).
MistakeCategory? classifyFailure({
  required ChallengeTag tag,
  required Duration elapsed,
  required Duration duration,
  required bool timedOut,
}) {
  switch (tag) {
    case ChallengeTag.memory:
      return MistakeCategory.memoryFailure;
    case ChallengeTag.counting:
      return MistakeCategory.countingFailure;
    case ChallengeTag.reaction:
    case ChallengeTag.patience:
      return MistakeCategory.timingFailure;
    case ChallengeTag.color:
    case ChallengeTag.word:
    case ChallengeTag.perception:
    case ChallengeTag.trick:
      break;
  }

  if (timedOut) {
    return MistakeCategory.timingFailure;
  }

  // A single fast wrong tap near the start reads as impulse.
  final limitMs = duration.inMilliseconds;
  if (limitMs > 0 && elapsed.inMilliseconds < limitMs * 0.35) {
    return MistakeCategory.impulsiveTap;
  }

  return null;
}

/// The Director's eyes: attaches to a [GameEngine], observes round events,
/// updates a [PlayerGameplayProfile] and persists it under `ayu.profile`.
///
/// Never blocks gameplay: event handling is synchronous and cheap, and a
/// malformed persisted profile falls back to an empty one rather than
/// throwing in the game loop.
class TelemetryCollector {
  TelemetryCollector({
    required SharedPreferences prefs,
    GameEngine? engine,
    int window = kProfileWindow,
    double emaAlpha = kEmaAlpha,
  })  : _prefs = prefs,
        _window = window,
        _alpha = emaAlpha {
    _engine = engine;
    if (engine != null) {
      engine.addEventListener(_onEvent);
    }
  }

  final SharedPreferences _prefs;
  final int _window;
  final double _alpha;

  GameEngine? _engine;
  PlayerGameplayProfile _profile = PlayerGameplayProfile();
  PlayerGameplayProfile get profile => _profile;

  final List<RoundObserved> _rounds = [];
  int _sessionFastStreak = 0;

  // Monotonic counters seeded from the persisted profile and kept in memory
  // for the lifetime of the collector — never re-derived from the profile
  // each recompute (which would double-count across a run).
  int _allTime = 0;
  int _fastestStreak = 0;

  /// Loads the persisted profile (empty on missing/corrupt data).
  Future<PlayerGameplayProfile> load() async {
    final raw = _prefs.getString(kProfileKey);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          _profile = PlayerGameplayProfile.fromJson(decoded);
        }
      } catch (_) {
        _profile = PlayerGameplayProfile();
      }
    }
    _allTime = _profile.totalRoundsPlayed;
    _fastestStreak = _profile.fastestStreak;
    return _profile;
  }

  /// Detaches from the engine (call from `dispose`).
  void detach() {
    final engine = _engine;
    if (engine != null) {
      engine.removeEventListener(_onEvent);
    }
    _engine = null;
  }

  void _onEvent(GameEvent event, GameState state) {
    switch (event) {
      case GameEvent.runStarted:
        _sessionFastStreak = 0;
        _rounds.clear();
        // Without this, `profile` stays stale until the next observed round
        // recomputes it — `_recompute()` was only ever called from
        // `_observe()`, so a restart with no rounds played yet still showed
        // last run's windowed `successRateByMechanic`/etc. `totalRoundsPlayed`
        // is unaffected either way — it's `_allTime`, never derived from
        // `_rounds`. Caught by test/ai/telemetry_test.dart's "a run restart
        // clears the in-run window but keeps all-time counters", pre-existing
        // and unrelated to any multiplayer work.
        _recompute();
        break;
      case GameEvent.correct:
        _sessionFastStreak = state.fastStreak;
        if (state.fastStreak > _fastestStreak) _fastestStreak = state.fastStreak;
        _observe(state: state, outcome: 'correct');
        break;
      case GameEvent.wrong:
        _observe(state: state, outcome: 'wrong');
        _sessionFastStreak = 0;
        break;
      case GameEvent.levelStarted:
      case GameEvent.gameOver:
      case GameEvent.continued:
        break;
    }
  }

  void _observe({required GameState state, required String outcome}) {
    final challenge = state.challenge;
    if (challenge == null) return;
    _allTime += 1;
    MistakeCategory? mistake;
    if (outcome != 'correct') {
      mistake = classifyFailure(
        tag: challenge.tag,
        elapsed: state.elapsed,
        duration: state.duration,
        timedOut: false,
      );
    }
    _rounds.add(RoundObserved(
      level: state.level,
      mechanicId: challenge.id,
      sessionFastStreak: _sessionFastStreak,
      reactionTimeMs: outcome == 'correct' ? state.elapsed.inMilliseconds : null,
      timeLimitMs: state.duration.inMilliseconds,
      outcome: outcome,
      mistake: mistake,
    ));
    if (_rounds.length > _window) _rounds.removeAt(0);
    _recompute();
  }

  void _recompute() {
    final successes = <String, int>{};
    final totalByMechanic = <String, int>{};
    final categoryCounts = <String, int>{};
    var failures = 0;
    final reactionTimes = <int>[];
    final levelWins = <int, int>{};
    final levelTotal = <int, int>{};

    for (final r in _rounds) {
      if (r.sessionFastStreak > _fastestStreak) _fastestStreak = r.sessionFastStreak;
      totalByMechanic[r.mechanicId] = (totalByMechanic[r.mechanicId] ?? 0) + 1;
      levelTotal[r.level] = (levelTotal[r.level] ?? 0) + 1;
      if (r.outcome == 'correct') {
        successes[r.mechanicId] = (successes[r.mechanicId] ?? 0) + 1;
        levelWins[r.level] = (levelWins[r.level] ?? 0) + 1;
        final rt = r.reactionTimeMs;
        if (rt != null) reactionTimes.add(rt);
      } else {
        failures += 1;
        if (r.mistake != null) {
          categoryCounts[r.mistake!.name] = (categoryCounts[r.mistake!.name] ?? 0) + 1;
        }
      }
    }

    final successRateByMechanic = <String, double>{
      for (final e in totalByMechanic.entries)
        e.key: (successes[e.key] ?? 0) / e.value,
    };
    final mistakeRates = <String, double>{
      for (final e in categoryCounts.entries)
        e.key: failures == 0 ? 0.0 : e.value / failures,
    };
    final winRateByDifficulty = <int, double>{
      for (final e in levelTotal.entries)
        e.key: (levelWins[e.key] ?? 0) / e.value,
    };

    _profile = PlayerGameplayProfile(
      totalRoundsPlayed: _allTime,
      fastestStreak: _fastestStreak,
      successRateByMechanic: successRateByMechanic,
      mistakeRatesByCategory: mistakeRates,
      averageReactionTimeMs: _compositeMean(reactionTimes),
      reactionTimeVarianceMs: _variance(reactionTimes),
      winRateByDifficulty: winRateByDifficulty,
    );
  }

  double? _compositeMean(List<int> values) {
    if (values.isEmpty) return _profile.averageReactionTimeMs;
    final windowMean = values.reduce((a, b) => a + b) / values.length;
    if (values.length >= _window || _profile.averageReactionTimeMs == null) {
      return windowMean;
    }
    return _alpha * windowMean + (1 - _alpha) * _profile.averageReactionTimeMs!;
  }

  double? _variance(List<int> values) {
    if (values.length < 2) return null;
    final m = values.reduce((a, b) => a + b) / values.length;
    return values.map((t) => (t - m) * (t - m)).reduce((a, b) => a + b) /
        values.length;
  }

  /// Persists the current profile (fire-and-forget).
  Future<void> persist() => _prefs.setString(kProfileKey, jsonEncode(_profile.toJson()));

  /// Hard wipe (Settings → RESET STATS): clears the session and disk copy.
  Future<void> reset() async {
    _rounds.clear();
    _sessionFastStreak = 0;
    _allTime = 0;
    _fastestStreak = 0;
    _profile = PlayerGameplayProfile();
    await _prefs.remove(kProfileKey);
  }
}
