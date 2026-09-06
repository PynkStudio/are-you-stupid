/// Difficulty curve. One place, so it can be tuned without touching gameplay.
library;

import 'dart:math';

class Difficulty {
  const Difficulty._();

  /// Time-limit multiplier. Everything gets faster, but never absurd.
  ///
  /// Levels 1-2 ramp up *into* the old flat 0.85 instead of starting there:
  /// a brand-new player's very first challenge used to run at the same pace
  /// as their third, which was plenty of time to know the game but not
  /// enough to have learned it yet. Level 3 onward is untouched.
  static double speedForLevel(int level) {
    if (level <= 1) return 0.60;
    if (level == 2) return 0.73;
    if (level <= 3) return 0.85; // still deliberately generous
    final s = 1.0 + (level - 3) * 0.042;
    return min(s, 2.35);
  }

  /// Minimum level before "mean" templates unlock.
  static bool allowsTricks(int level) => level >= 6;

  /// Whether the depleting timer bar itself is visible, on top of whatever a
  /// challenge's own `showTimer` already decides. Hidden from the same level
  /// "mean" templates unlock: not knowing how much time is left becomes part
  /// of the difficulty, same as [allowsTricks] not knowing the rules.
  static bool showTimerBar(int level) => !allowsTricks(level);

  /// A one-line "the game just changed" callout, shown once the first time
  /// [level] is reached. Returns an `ui.game.milestone.*` key, or null.
  static String? milestoneKey(int level) {
    if (level == 4) return 'ui.game.milestone.faster';
    if (level == 6) return 'ui.game.milestone.no_timer';
    return null;
  }

  /// How often a viral prompt is allowed to show up.
  static bool showViralPrompt(int level) => level > 0 && level % 12 == 0;

  /// Levels considered "warm up": only starter templates.
  static bool isStarter(int level) => level <= 3;

  /// Rough band used by some challenges to add noise (0..1).
  static double heat(int level) => min(1.0, max(0.0, (level - 3) / 30.0));
}
