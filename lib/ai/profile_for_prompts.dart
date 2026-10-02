/// `ProfileForPrompts` — the truncation facade [[Dynamic Profiles and Tool
/// Calling]] describes for `GetPlayerProfileTool`: the *only* shape of
/// [PlayerGameplayProfile] that's ever allowed to leave the device toward a
/// model prompt.
///
/// Deliberately narrower than [PlayerGameplayProfile] itself — no
/// `winRateByDifficulty`, no `mistakeRatesByCategory` breakdown, no
/// `totalRoundsPlayed`, nothing that could look like an identifier. Success
/// rates are rounded to the nearest 10% (never the precise windowed value)
/// per [[Privacy and Offline]]'s "what enters a prompt" table.
///
/// This file is PURE DART: no Flutter imports.
library;

import 'telemetry.dart';

/// Builds the wire payload `AYSChallengeGenerationService`
/// (`ios/Runner/AppleAIService/ChallengeGenerationProfile.swift`) unpacks
/// into `AYSPlayerProfileSnapshot`. `profile == null` (cold start) yields
/// the same shape with neutral defaults — never omits the key entirely, so
/// the Swift side never has to special-case "no profile yet."
Map<String, Object?> profileForPrompts(PlayerGameplayProfile? profile) {
  if (profile == null) {
    return const {
      'mostCommonMistakeCategory': '',
      'successRateByMechanic': <String>[],
      'averageReactionTimeMs': 0,
      'fastestStreak': 0,
    };
  }
  return {
    'mostCommonMistakeCategory': profile.mostCommonMistakeCategory ?? '',
    'successRateByMechanic': [
      for (final entry in profile.successRateByMechanic.entries)
        '${entry.key}:${_roundedToTenPercent(entry.value)}',
    ],
    'averageReactionTimeMs': profile.averageReactionTimeMs?.round() ?? 0,
    'fastestStreak': profile.fastestStreak,
  };
}

/// Rounds a 0..1 rate to the nearest 10% — `0.0`, `0.1`, ..., `1.0` — the
/// coarsest granularity [[Privacy and Offline]] allows into a prompt.
double _roundedToTenPercent(double rate) => (rate * 10).round() / 10;
