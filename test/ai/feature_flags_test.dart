import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:are_you_stupid/ai/feature_flags.dart';

Future<AiFeatureFlags> _flags([Map<String, Object>? initial]) async {
  SharedPreferences.setMockInitialValues(initial ?? {});
  return AiFeatureFlags.load();
}

void main() {
  group('defaults (nothing persisted)', () {
    test('every flag matches the documented default posture', () async {
      final flags = await _flags();
      expect(flags.dynamicAIEnabled, isTrue);
      expect(flags.aiChallengeGenerationEnabled, isTrue);
      expect(flags.aiCommentaryEnabled, isTrue);
      expect(flags.aiAdaptiveDifficultyEnabled, isFalse); // the one off-by-default flag
      expect(flags.aiMultiplayerDirectorEnabled, isTrue);
      expect(flags.aiFailoverEnabled, isTrue);
      expect(flags.aiObservabilityEnabled, isTrue);
      expect(flags.mode, AiExperienceMode.genius);
    });
  });

  group('master switch short-circuits every sub-flag', () {
    test('dynamicAIEnabled=false forces every sub-flag to read false', () async {
      final flags = await _flags();
      await flags.setDynamicAIEnabled(false);

      expect(flags.dynamicAIEnabled, isFalse);
      expect(flags.aiChallengeGenerationEnabled, isFalse);
      expect(flags.aiCommentaryEnabled, isFalse);
      expect(flags.aiAdaptiveDifficultyEnabled, isFalse);
      expect(flags.aiMultiplayerDirectorEnabled, isFalse);
      expect(flags.aiFailoverEnabled, isFalse);
      expect(flags.aiObservabilityEnabled, isFalse);
    });

    test('re-enabling the master restores the underlying sub-flag values', () async {
      final flags = await _flags();
      await flags.setCommentaryEnabled(false);
      await flags.setDynamicAIEnabled(false);
      expect(flags.aiCommentaryEnabled, isFalse); // masked by master
      await flags.setDynamicAIEnabled(true);
      expect(flags.aiCommentaryEnabled, isFalse); // the sub-flag's own value survived
      expect(flags.aiChallengeGenerationEnabled, isTrue); // untouched sub-flag
    });
  });

  group('persistence', () {
    test('individual setters persist across a fresh load', () async {
      SharedPreferences.setMockInitialValues({});
      final first = await AiFeatureFlags.load();
      await first.setChallengeGenerationEnabled(false);
      await first.setAdaptiveDifficultyEnabled(true);

      final reloaded = await AiFeatureFlags.load();
      expect(reloaded.aiChallengeGenerationEnabled, isFalse);
      expect(reloaded.aiAdaptiveDifficultyEnabled, isTrue);
    });
  });

  group('mode <-> flag mapping', () {
    test('genius sets every mode-controlled flag on', () async {
      final flags = await _flags();
      await flags.setDynamicAIEnabled(false);
      await flags.setCommentaryEnabled(false);

      await flags.setMode(AiExperienceMode.genius);

      expect(flags.mode, AiExperienceMode.genius);
      expect(flags.dynamicAIEnabled, isTrue);
      expect(flags.aiChallengeGenerationEnabled, isTrue);
      expect(flags.aiCommentaryEnabled, isTrue);
      expect(flags.aiMultiplayerDirectorEnabled, isTrue);
      expect(flags.aiFailoverEnabled, isTrue);
      expect(flags.aiObservabilityEnabled, isTrue);
    });

    test('focused sets the same flags as genius', () async {
      final flags = await _flags();
      await flags.setMode(AiExperienceMode.focused);

      expect(flags.mode, AiExperienceMode.focused);
      expect(flags.dynamicAIEnabled, isTrue);
      expect(flags.aiChallengeGenerationEnabled, isTrue);
      expect(flags.aiCommentaryEnabled, isTrue);
      expect(flags.aiMultiplayerDirectorEnabled, isTrue);
      expect(flags.aiFailoverEnabled, isTrue);
    });

    test('classic only flips the master switch', () async {
      final flags = await _flags();
      await flags.setMode(AiExperienceMode.classic);

      expect(flags.mode, AiExperienceMode.classic);
      expect(flags.dynamicAIEnabled, isFalse);
      // every sub-flag reads false only because the master masks it
      expect(flags.aiChallengeGenerationEnabled, isFalse);
    });

    test('adaptive difficulty is never touched by a mode switch', () async {
      final flags = await _flags();
      await flags.setAdaptiveDifficultyEnabled(true);

      await flags.setMode(AiExperienceMode.classic);
      await flags.setDynamicAIEnabled(true); // undo classic's master flip
      expect(flags.aiAdaptiveDifficultyEnabled, isTrue);

      await flags.setMode(AiExperienceMode.genius);
      expect(flags.aiAdaptiveDifficultyEnabled, isTrue);
    });

    test('an unrecognized persisted mode name falls back to genius', () async {
      final flags = await _flags({'ayu.dynamicAI.mode': 'nonsense'});
      expect(flags.mode, AiExperienceMode.genius);
    });
  });
}
