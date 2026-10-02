/// Difficulty curve. One place, so it can be tuned without touching gameplay.
library;

import 'dart:math';

class Difficulty {
  const Difficulty._();

  /// Time-limit multiplier. `params.pace(base, floorMs: min)` computes
  /// `base / speed`, clamped to `min` — so every challenge's own `base`
  /// constant is the *most* time it ever gets (reached at level 1-2) and
  /// its `floorMs` is the *least* (approached at the highest levels), with
  /// this stepped table deciding how much of that range level [level] gets.
  ///
  /// Levels 1-9 are the tutorial: nine gentle steps that only nudge the
  /// pace, so a new player never feels the game "snap" faster round to
  /// round. From level 10 the game is meant to feel alive, stepping up
  /// every ten levels — still capped well below the old asymptote (2.35),
  /// so even the highest levels stay a little more generous than before.
  /// See [[Difficulty Curve]] for the full table and the reasoning.
  static double speedForLevel(int level) {
    if (level <= 2) return 0.49;
    if (level <= 4) return 0.52;
    if (level <= 6) return 0.56;
    if (level <= 9) return 0.65;
    if (level <= 19) return 0.82;
    if (level <= 29) return 1.05;
    if (level <= 39) return 1.29;
    if (level <= 49) return 1.52;
    return 1.76;
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
    if (level == 6) return 'ui.game.milestone.no_timer';
    if (level == 10) return 'ui.game.milestone.faster';
    return null;
  }

  /// How often a viral prompt is allowed to show up.
  static bool showViralPrompt(int level) => level > 0 && level % 12 == 0;

  /// Levels considered "warm up": only starter templates.
  static bool isStarter(int level) => level <= 3;

  /// Rough band used by some challenges to add noise (0..1).
  static double heat(int level) => min(1.0, max(0.0, (level - 3) / 30.0));
}
