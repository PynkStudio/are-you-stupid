import 'challenge.dart';

enum GamePhase {
  /// Nothing running (menu).
  idle,

  /// Short "GET READY" beat before the very first challenge.
  intro,

  /// A challenge is live.
  playing,

  /// Green flash after a correct answer.
  correct,

  /// Red flash after a mistake.
  wrong,

  /// Run is over.
  gameOver,
}

/// Immutable-ish snapshot of the current run. Read by the UI, written by the
/// engine only.
class GameState {
  GameState.initial()
      : phase = GamePhase.idle,
        level = 1,
        challenge = null,
        elapsed = Duration.zero,
        duration = Duration.zero,
        flashMessage = null,
        successNote = null,
        fastStreak = 0,
        bestFastStreak = 0,
        continueUsed = false,
        viralPrompt = null;

  GameState({
    required this.phase,
    required this.level,
    required this.challenge,
    required this.elapsed,
    required this.duration,
    required this.flashMessage,
    required this.successNote,
    required this.fastStreak,
    required this.bestFastStreak,
    required this.continueUsed,
    required this.viralPrompt,
  });

  final GamePhase phase;

  /// The level currently being played. Score = highest level reached.
  final int level;

  final Challenge? challenge;
  final Duration elapsed;
  final Duration duration;

  /// Roast / feedback line shown during the flash.
  final String? flashMessage;

  /// e.g. "+0.13s".
  final String? successNote;

  final int fastStreak;
  final int bestFastStreak;
  final bool continueUsed;

  /// Occasional "send this to someone who thinks they're smart" line.
  final String? viralPrompt;

  double get progress {
    if (duration.inMilliseconds <= 0) return 0;
    final p = elapsed.inMilliseconds / duration.inMilliseconds;
    return p.clamp(0.0, 1.0);
  }

  /// Score of the finished run: the highest level reached.
  int get reachedLevel => level;

  GameState copyWith({
    GamePhase? phase,
    int? level,
    Challenge? challenge,
    bool clearChallenge = false,
    Duration? elapsed,
    Duration? duration,
    String? flashMessage,
    bool clearFlash = false,
    String? successNote,
    bool clearNote = false,
    int? fastStreak,
    int? bestFastStreak,
    bool? continueUsed,
    String? viralPrompt,
    bool clearViral = false,
  }) {
    return GameState(
      phase: phase ?? this.phase,
      level: level ?? this.level,
      challenge: clearChallenge ? null : (challenge ?? this.challenge),
      elapsed: elapsed ?? this.elapsed,
      duration: duration ?? this.duration,
      flashMessage: clearFlash ? null : (flashMessage ?? this.flashMessage),
      successNote: clearNote ? null : (successNote ?? this.successNote),
      fastStreak: fastStreak ?? this.fastStreak,
      bestFastStreak: bestFastStreak ?? this.bestFastStreak,
      continueUsed: continueUsed ?? this.continueUsed,
      viralPrompt: clearViral ? null : (viralPrompt ?? this.viralPrompt),
    );
  }
}
