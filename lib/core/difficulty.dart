/// Difficulty curve. One place, so it can be tuned without touching gameplay.
library;

import 'dart:math';

class Difficulty {
  const Difficulty._();

  /// Time-limit multiplier. Everything gets faster, but never absurd.
  static double speedForLevel(int level) {
    if (level <= 3) return 0.85; // first levels are deliberately generous
    final s = 1.0 + (level - 3) * 0.042;
    return min(s, 2.35);
  }

  /// Minimum level before "mean" templates unlock.
  static bool allowsTricks(int level) => level >= 6;

  /// How often a viral prompt is allowed to show up.
  static bool showViralPrompt(int level) => level > 0 && level % 12 == 0;

  /// Levels considered "warm up": only starter templates.
  static bool isStarter(int level) => level <= 3;

  /// Rough band used by some challenges to add noise (0..1).
  static double heat(int level) => min(1.0, max(0.0, (level - 3) / 30.0));
}
