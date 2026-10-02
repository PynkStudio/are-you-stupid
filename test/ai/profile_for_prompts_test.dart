import 'package:flutter_test/flutter_test.dart';
import 'package:are_you_stupid/ai/challenge_vocabulary.dart';
import 'package:are_you_stupid/ai/profile_for_prompts.dart';
import 'package:are_you_stupid/ai/telemetry.dart';

void main() {
  group('profileForPrompts', () {
    test('cold start (null profile) yields neutral defaults, never omits keys', () {
      final payload = profileForPrompts(null);
      expect(payload['mostCommonMistakeCategory'], '');
      expect(payload['successRateByMechanic'], isEmpty);
      expect(payload['averageReactionTimeMs'], 0);
      expect(payload['fastestStreak'], 0);
    });

    test('rounds success rates to the nearest 10%, never leaks the raw value', () {
      final profile = PlayerGameplayProfile(
        fastestStreak: 5,
        successRateByMechanic: const {'tap_true_color': 0.74},
        averageReactionTimeMs: 611.4,
      );
      final payload = profileForPrompts(profile);
      expect(payload['successRateByMechanic'], ['tap_true_color:0.7']);
      expect(payload['averageReactionTimeMs'], 611);
      expect(payload['fastestStreak'], 5);
    });

    test('only the four allowed fields are ever present — nothing identifying', () {
      final profile = PlayerGameplayProfile(
        fastestStreak: 1,
        successRateByMechanic: const {'a': 0.5},
      );
      final payload = profileForPrompts(profile);
      expect(
        payload.keys.toSet(),
        {
          'mostCommonMistakeCategory',
          'successRateByMechanic',
          'averageReactionTimeMs',
          'fastestStreak',
        },
      );
    });
  });

  group('availableMechanicMoves', () {
    test('without tricks, every requiresTrick mechanic is excluded', () {
      final moves = availableMechanicMoves(allowTricks: false);
      for (final move in moves) {
        expect(kMechanicByMove[move]!.requiresTrick, isFalse);
      }
      expect(moves, isNot(contains('dont_tap_odd'))); // requiresTrick: true
    });

    test('with tricks allowed, every mechanic is eligible', () {
      final moves = availableMechanicMoves(allowTricks: true);
      expect(moves.length, kMechanicVocabulary.length);
      expect(moves, contains('dont_tap_odd'));
    });
  });
}
