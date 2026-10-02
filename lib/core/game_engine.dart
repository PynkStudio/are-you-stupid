import 'dart:math';

import 'package:flutter/foundation.dart';

import '../ai/providers.dart';
import '../data/roasts.dart';
import '../data/viral_prompts.dart';
import '../i18n/app_locale.dart';
import '../i18n/strings.dart';
import 'challenge.dart';
import 'difficulty.dart';
import 'game_state.dart';

/// Things the engine shouts about. The UI layer wires these to sound, haptics
/// and persistence — the engine itself knows nothing about them.
enum GameEvent {
  runStarted,
  levelStarted,
  correct,
  wrong,
  gameOver,
  continued,
}

typedef GameEventListener = void Function(GameEvent event, GameState state);

/// The whole run lives here. No widgets, no platform calls, no I/O.
class GameEngine extends ChangeNotifier implements ChallengeHost {
  GameEngine({
    required ChallengeProvider provider,
    Random? random,
    this.locale = AppLocale.en,
  })  : _provider = provider,
        _rng = random ?? Random();

  /// Where the next challenge comes from. The engine never knows the source —
  /// compatible from the engine's by-document posture, `core/` stays source-
  /// agnostic. The UI composes a [FallbackChallengeProvider] front-to-back
  /// ([[Development Plan]] Phase 1).
  final ChallengeProvider _provider;
  final Random _rng;

  /// The player's current language. Flows into every [ChallengeContext] so
  /// the next round's challenge is built in that language.
  AppLocale locale;

  final List<GameEventListener> _listeners = [];

  /// Mirrors the "SAVAGE MODE" setting. When false only neutral lines show up.
  bool spicyRoasts = true;

  GameState _state = GameState.initial();
  GameState get state => _state;

  /// How long the flashes last. Correct stays tiny: downtime kills the loop.
  /// Wrong is long enough to actually read the roast — see
  /// `docs/Meta/Decision Log.md` — but [skipWrongFlash] lets an impatient
  /// player cut it short, so a player who already knows the drill still gets
  /// near-zero downtime.
  static const introDuration = Duration(milliseconds: 550);
  static const correctFlash = Duration(milliseconds: 240);
  static const wrongFlash = Duration(milliseconds: 2850);

  /// The first stretch of the wrong flash can't be skipped. Without it, the
  /// next tap of a player mashing a tap-N-times challenge skips the roast
  /// unread — breaking "every failure is explainable in one line" — and can
  /// land on a Game Over button. See `docs/Meta/Decision Log.md`.
  static const wrongFlashSkipGrace = Duration(milliseconds: 500);

  Duration _phaseElapsed = Duration.zero;

  void addEventListener(GameEventListener listener) => _listeners.add(listener);
  void removeEventListener(GameEventListener listener) =>
      _listeners.remove(listener);

  void _emit(GameEvent event) {
    for (final l in List.of(_listeners)) {
      l(event, _state);
    }
  }

  // ---------------------------------------------------------------- lifecycle

  void startRun() {
    _provider.reset();
    _phaseElapsed = Duration.zero;
    _state = GameState.initial().copyWith(phase: GamePhase.intro, level: 1);
    _emit(GameEvent.runStarted);
    notifyListeners();
  }

  void abandonRun() {
    _phaseElapsed = Duration.zero;
    _state = GameState.initial();
    notifyListeners();
  }

  /// Resume the run from the level where it ended. One per run.
  ///
  /// Goes through the READY beat like a fresh run, so a player coming back
  /// from a rewarded ad isn't dropped into a level with the timer running.
  void continueRun() {
    if (!_state.continueUsed) {
      _state = _state.copyWith(continueUsed: true);
    }
    _phaseElapsed = Duration.zero;
    _state = _state.copyWith(phase: GamePhase.intro);
    _emit(GameEvent.continued);
    notifyListeners();
  }

  void _startLevel(int level) {
    final context = ChallengeContext(
      level: level,
      locale: locale,
      allowTricks: Difficulty.allowsTricks(level),
    );
    final generated = _provider.next(context);
    final challenge = generated?.challenge;
    if (challenge == null) {
      // Contract: a composed provider (Fallback → scripted) never returns
      // null. Defend anyway: stay in the intro beat and re-ask next tick —
      // a broken composition shows up as a stuck intro, never a crash.
      assert(false,
          'ChallengeProvider.next() returned null at level $level');
      return;
    }
    final milestoneKey = Difficulty.milestoneKey(level);
    _phaseElapsed = Duration.zero;
    _state = _state.copyWith(
      phase: GamePhase.playing,
      level: level,
      challenge: challenge,
      elapsed: Duration.zero,
      duration: challenge.duration,
      clearFlash: true,
      clearNote: true,
      viralPrompt: Difficulty.showViralPrompt(level)
          ? ViralPrompts.random(locale, _rng)
          : null,
      clearViral: !Difficulty.showViralPrompt(level),
      paceNote: milestoneKey != null ? Strings.t(locale, milestoneKey) : null,
      clearPaceNote: milestoneKey == null,
    );
    challenge.onStart(this);
    if (_state.phase == GamePhase.playing) {
      _emit(GameEvent.levelStarted);
    }
    notifyListeners();
  }

  // -------------------------------------------------------------------- clock

  /// Drive from a Ticker. [delta] is the time since the previous frame.
  void tick(Duration delta) {
    switch (_state.phase) {
      case GamePhase.idle:
      case GamePhase.gameOver:
        return;
      case GamePhase.intro:
        _phaseElapsed += delta;
        if (_phaseElapsed >= introDuration) _startLevel(_state.level);
        return;
      case GamePhase.correct:
        _phaseElapsed += delta;
        if (_phaseElapsed >= correctFlash) _startLevel(_state.level + 1);
        return;
      case GamePhase.wrong:
        _phaseElapsed += delta;
        if (_phaseElapsed >= wrongFlash) _enterGameOver();
        return;
      case GamePhase.playing:
        break;
    }

    final challenge = _state.challenge;
    if (challenge == null) return;

    final elapsed = _state.elapsed + delta;
    _state = _state.copyWith(elapsed: elapsed);
    challenge.onTick(elapsed, this);

    // The challenge may have ended the round inside onTick.
    if (_state.phase != GamePhase.playing) return;

    if (elapsed >= _state.duration) {
      challenge.onTimeout(this);
    }
    notifyListeners();
  }

  // ------------------------------------------------------------------- inputs

  void handleTap(TapInfo tap) {
    if (_state.phase != GamePhase.playing) return;
    final challenge = _state.challenge;
    if (challenge == null) return;
    challenge.onTap(tap.copyWithElapsed(_state.elapsed), this);
    notifyListeners();
  }

  /// Lets the player cut the wrong-flash roast short instead of waiting out
  /// [wrongFlash] — a no-op outside that phase.
  void skipWrongFlash() {
    if (_state.phase != GamePhase.wrong) return;
    if (_phaseElapsed < wrongFlashSkipGrace) return;
    _enterGameOver();
  }

  void _enterGameOver() {
    _phaseElapsed = Duration.zero;
    _state = _state.copyWith(phase: GamePhase.gameOver);
    _emit(GameEvent.gameOver);
    notifyListeners();
  }

  // -------------------------------------------------------- ChallengeHost API

  @override
  void pass({String? note}) {
    if (_state.phase != GamePhase.playing) return;
    final fast = _state.duration.inMilliseconds > 0 &&
        _state.elapsed.inMilliseconds < _state.duration.inMilliseconds * 0.45;
    final streak = fast ? _state.fastStreak + 1 : 0;
    _phaseElapsed = Duration.zero;
    _state = _state.copyWith(
      phase: GamePhase.correct,
      successNote: note ?? _state.challenge?.successNote,
      clearNote: note == null && _state.challenge?.successNote == null,
      fastStreak: streak,
      bestFastStreak: max(streak, _state.bestFastStreak),
    );
    _emit(GameEvent.correct);
    notifyListeners();
  }

  @override
  void fail({String? reason}) {
    if (_state.phase != GamePhase.playing) return;
    _phaseElapsed = Duration.zero;
    _state = _state.copyWith(
      phase: GamePhase.wrong,
      flashMessage: reason ??
          Roasts.forMistake(rng: _rng, allowSpicy: spicyRoasts, locale: locale),
      fastStreak: 0,
    );
    _emit(GameEvent.wrong);
    notifyListeners();
  }

  @override
  void invalidate() => notifyListeners();
}

extension on TapInfo {
  TapInfo copyWithElapsed(Duration elapsed) => TapInfo(
        targetId: targetId,
        elapsed: elapsed,
        kind: kind,
        index: index,
      );
}
