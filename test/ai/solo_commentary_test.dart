import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:are_you_stupid/ai/apple_ai_service.dart';
import 'package:are_you_stupid/ai/commentary.dart';
import 'package:are_you_stupid/ai/feature_flags.dart';
import 'package:are_you_stupid/ai/solo_commentary.dart';
import 'package:are_you_stupid/i18n/app_locale.dart';

Future<AiFeatureFlags> _flags() async {
  SharedPreferences.setMockInitialValues({});
  return AiFeatureFlags.load();
}

/// Lets the fire-and-forget prefetch future resolve.
Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  group('isCommentaryLineValid — localized lines', () {
    test('a non-English line may use accented Latin letters', () {
      expect(
        isCommentaryLineValid('Perfino un pesce ci sarebbe riuscito, però.',
            CommentaryKind.wrong,
            locale: AppLocale.it),
        isTrue,
      );
      expect(
        isCommentaryLineValid('¿En serio fallaste eso?', CommentaryKind.wrong,
            locale: AppLocale.es),
        isTrue,
      );
    });

    test('English stays strict ASCII', () {
      expect(
        isCommentaryLineValid('Très bien.', CommentaryKind.correct),
        isFalse,
      );
    });

    test('emoji and non-Latin scripts are rejected in every locale', () {
      expect(
        isCommentaryLineValid('Bravo 🎉', CommentaryKind.correct,
            locale: AppLocale.it),
        isFalse,
      );
      expect(
        isCommentaryLineValid('Привет.', CommentaryKind.correct,
            locale: AppLocale.de),
        isFalse,
      );
    });

    test('localized meta-AI references are rejected', () {
      expect(
        isCommentaryLineValid('Il modello è deluso.', CommentaryKind.wrong,
            locale: AppLocale.it),
        isFalse,
      );
      expect(
        isCommentaryLineValid('Die KI lacht dich aus.', CommentaryKind.wrong,
            locale: AppLocale.de),
        isFalse,
      );
    });

    test('normalizeCommentaryLine strips the quotes models wrap lines in', () {
      expect(normalizeCommentaryLine(' "Nice one." '), 'Nice one.');
      expect(normalizeCommentaryLine('«Pas mal.»'), 'Pas mal.');
    });
  });

  group('CommentaryProvider.aiLine', () {
    test('returns null instead of a static line when the model is unavailable',
        () async {
      final service = MockAppleAIService()
        ..availability = const AppleAiAvailability('unavailable');
      final provider =
          CommentaryProvider(service: service, flags: await _flags());

      expect(
        await provider.aiLine(kind: CommentaryKind.wrong, locale: AppLocale.it),
        isNull,
      );
    });

    test('passes the locale and spicy setting through to the bridge', () async {
      final service = MockAppleAIService()
        ..nextCommentaryResult = const AppleAiTextResult.ok('"Che disastro."');
      final provider =
          CommentaryProvider(service: service, flags: await _flags());

      final line = await provider.aiLine(
        kind: CommentaryKind.wrong,
        locale: AppLocale.it,
        allowSpicy: false,
      );

      expect(line, 'Che disastro.');
      final payload = service.calls['requestCommentary']!.single;
      expect(payload['locale'], 'it');
      expect((payload['context'] as Map)['spicy'], isFalse);
    });
  });

  group('SoloCommentator', () {
    test('keeps one wrong aside ready and serves it exactly once', () async {
      final service = MockAppleAIService()
        ..nextCommentaryResult = const AppleAiTextResult.ok('Impressive, in a way.');
      final commentator = SoloCommentator(
        provider: CommentaryProvider(service: service, flags: await _flags()),
      );

      expect(commentator.takeWrongAside(), isNull); // cold: nothing yet

      commentator.warm(locale: AppLocale.en, allowSpicy: true, level: 3);
      await _settle();

      expect(commentator.takeWrongAside(), 'Impressive, in a way.');
      expect(commentator.takeWrongAside(), isNull); // every read is a pop
      final payload = service.calls['requestCommentary']!.single;
      expect(payload['kind'], 'wrong');
      expect((payload['context'] as Map)['level'], 3);
    });

    test('a locale change drops the aside written for the old language',
        () async {
      final service = MockAppleAIService()
        ..nextCommentaryResult = const AppleAiTextResult.ok('Not great.');
      final commentator = SoloCommentator(
        provider: CommentaryProvider(service: service, flags: await _flags()),
      );
      commentator.warm(locale: AppLocale.en, allowSpicy: true, level: 1);
      await _settle();

      service.nextCommentaryResult = const AppleAiTextResult.ok('Non benissimo.');
      commentator.warm(locale: AppLocale.it, allowSpicy: true, level: 2);
      await _settle();

      expect(commentator.takeWrongAside(), 'Non benissimo.');
    });

    test('flag off: no aside, no verdict, no bridge traffic', () async {
      final flags = await _flags();
      await flags.setCommentaryEnabled(false);
      final service = MockAppleAIService();
      final commentator = SoloCommentator(
        provider: CommentaryProvider(service: service, flags: flags),
      );

      commentator.warm(locale: AppLocale.en, allowSpicy: true, level: 1);
      await _settle();

      expect(commentator.takeWrongAside(), isNull);
      expect(
        await commentator.verdict(
          locale: AppLocale.en,
          allowSpicy: true,
          run: const RunSummary(level: 4, best: 9, newBest: false, bestStreak: 0),
        ),
        isNull,
      );
      expect(service.calls.containsKey('requestCommentary'), isFalse);
    });

    test('the verdict is a gameOver line written from the run facts', () async {
      final service = MockAppleAIService()
        ..nextCommentaryResult =
            const AppleAiTextResult.ok('Level seven, beaten by a red square.');
      final commentator = SoloCommentator(
        provider: CommentaryProvider(service: service, flags: await _flags()),
      );

      final line = await commentator.verdict(
        locale: AppLocale.en,
        allowSpicy: true,
        run: const RunSummary(
          level: 7,
          best: 5,
          newBest: true,
          bestStreak: 4,
          failedInstruction: 'TAP RED',
          failReason: 'THAT WAS BLUE.',
        ),
      );

      expect(line, 'Level seven, beaten by a red square.');
      final payload = service.calls['requestCommentary']!.single;
      expect(payload['kind'], 'gameOver');
      final context = payload['context'] as Map;
      expect(context['levelReached'], 7);
      expect(context['newPersonalBest'], 'yes');
      expect(context['failedInstruction'], 'TAP RED');
      expect(context['whyTheyFailed'], 'THAT WAS BLUE.');
    });
  });
}
