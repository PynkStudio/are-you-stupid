import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:are_you_stupid/ai/apple_ai_service.dart';
import 'package:are_you_stupid/ai/commentary.dart';
import 'package:are_you_stupid/ai/feature_flags.dart';
import 'package:are_you_stupid/i18n/app_locale.dart';

Future<AiFeatureFlags> _flags() async {
  SharedPreferences.setMockInitialValues({});
  return AiFeatureFlags.load();
}

void main() {
  group('isCommentaryLineValid', () {
    test('accepts a short, clean line', () {
      expect(isCommentaryLineValid('Nice one.', CommentaryKind.correct), isTrue);
    });

    test('rejects a line over the kind\'s word cap', () {
      const line = 'one two three four five six seven';
      expect(isCommentaryLineValid(line, CommentaryKind.correct), isFalse); // cap 6
      expect(isCommentaryLineValid(line, CommentaryKind.wrong), isTrue); // cap 12
    });

    test('rejects non-ASCII / emoji', () {
      expect(isCommentaryLineValid('Nice one! 🎉', CommentaryKind.correct), isFalse);
    });

    test('rejects a forbidden token', () {
      expect(isCommentaryLineValid('That was a Nazi move.', CommentaryKind.wrong), isFalse);
    });

    test('rejects a meta-AI reference', () {
      expect(isCommentaryLineValid('The AI is disappointed.', CommentaryKind.wrong), isFalse);
    });

    test('rejects more than one sentence', () {
      expect(isCommentaryLineValid('Nice one. Do it again.', CommentaryKind.correct), isFalse);
    });

    test('rejects an empty line', () {
      expect(isCommentaryLineValid('   ', CommentaryKind.wrong), isFalse);
    });
  });

  group('CommentaryProvider — static-bank-first ladder', () {
    test('flag off never touches the bridge', () async {
      final flags = await _flags();
      await flags.setCommentaryEnabled(false);
      final service = MockAppleAIService();
      final provider = CommentaryProvider(service: service, flags: flags, rng: Random(1));

      final text = await provider.line(kind: CommentaryKind.wrong, locale: AppLocale.en);

      expect(text, isNotEmpty);
      expect(service.calls.containsKey('requestCommentary'), isFalse);
    });

    test('model unavailable falls back to the static bank', () async {
      final flags = await _flags();
      final service = MockAppleAIService()
        ..availability = const AppleAiAvailability('unavailable');
      final provider = CommentaryProvider(service: service, flags: flags, rng: Random(1));

      final text = await provider.line(kind: CommentaryKind.correct, locale: AppLocale.en);

      expect(text, isNotEmpty);
      expect(service.calls.containsKey('requestCommentary'), isFalse);
    });

    test('a valid AI line is used and remembered', () async {
      final flags = await _flags();
      final service = MockAppleAIService()
        ..nextCommentaryResult = const AppleAiTextResult.ok('Barely made it.');
      final provider = CommentaryProvider(service: service, flags: flags, rng: Random(1));

      final text = await provider.line(kind: CommentaryKind.wrong, locale: AppLocale.en);

      expect(text, 'Barely made it.');
      final payload = service.calls['requestCommentary']!.single;
      expect(payload['kind'], 'wrong');
      expect(payload['locale'], 'en');
    });

    test('an invalid AI line (too long) falls back to the static bank', () async {
      final flags = await _flags();
      final service = MockAppleAIService()
        ..nextCommentaryResult =
            const AppleAiTextResult.ok('one two three four five six seven');
      final provider = CommentaryProvider(service: service, flags: flags, rng: Random(1));

      final text = await provider.line(kind: CommentaryKind.correct, locale: AppLocale.en);

      expect(text, isNot('one two three four five six seven'));
    });

    test('a bridge failure falls back to the static bank', () async {
      final flags = await _flags();
      final service = MockAppleAIService()
        ..nextCommentaryResult =
            const AppleAiTextResult.fail(AppleAiError('refusal'));
      final provider = CommentaryProvider(service: service, flags: flags, rng: Random(1));

      final text = await provider.line(kind: CommentaryKind.wrong, locale: AppLocale.en);

      expect(text, isNotEmpty);
    });

    test('a repeated line falls back instead of showing the same line twice', () async {
      final flags = await _flags();
      final service = MockAppleAIService()
        ..nextCommentaryResult = const AppleAiTextResult.ok('Nice one.');
      final provider = CommentaryProvider(service: service, flags: flags, rng: Random(1));

      final first = await provider.line(kind: CommentaryKind.correct, locale: AppLocale.en);
      expect(first, 'Nice one.');

      final second = await provider.line(kind: CommentaryKind.correct, locale: AppLocale.en);
      expect(second, isNot('Nice one.'));
    });

    test('a caller-supplied static fallback overrides the default pool', () async {
      final flags = await _flags();
      await flags.setCommentaryEnabled(false);
      final service = MockAppleAIService();
      final provider = CommentaryProvider(service: service, flags: flags);

      final text = await provider.line(
        kind: CommentaryKind.wrong,
        locale: AppLocale.en,
        staticFallback: () => 'CUSTOM LINE',
      );

      expect(text, 'CUSTOM LINE');
    });
  });
}
