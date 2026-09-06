import 'dart:math';

import 'package:are_you_stupid/challenges/registry.dart';
import 'package:are_you_stupid/core/challenge.dart';
import 'package:are_you_stupid/i18n/app_locale.dart';
import 'package:are_you_stupid/i18n/spell_count_data.dart';
import 'package:are_you_stupid/i18n/strings.dart';
import 'package:are_you_stupid/i18n/strings_de.dart';
import 'package:are_you_stupid/i18n/strings_en.dart';
import 'package:are_you_stupid/i18n/strings_es.dart';
import 'package:are_you_stupid/i18n/strings_fr.dart';
import 'package:are_you_stupid/i18n/strings_it.dart';
import 'package:are_you_stupid/i18n/strings_pt.dart';
import 'package:are_you_stupid/main.dart';
import 'package:are_you_stupid/services/app_services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Guards the one thing `Strings.t`'s English fallback can hide: a locale
/// file silently missing a key (or a `spell_count`/`opposite` entry that is
/// malformed) instead of failing loudly. See
/// `docs/Architecture/Localization.md`.
void main() {
  final tables = <AppLocale, Map<String, String>>{
    AppLocale.en: kStringsEn,
    AppLocale.it: kStringsIt,
    AppLocale.fr: kStringsFr,
    AppLocale.es: kStringsEs,
    AppLocale.pt: kStringsPt,
    AppLocale.de: kStringsDe,
  };

  test('every locale defines exactly the same keys as English', () {
    final enKeys = kStringsEn.keys.toSet();
    for (final locale in AppLocale.values) {
      if (locale == AppLocale.en) continue;
      expect(
        tables[locale]!.keys.toSet(),
        enKeys,
        reason: '$locale key set has drifted from strings_en.dart',
      );
    }
  });

  test('no locale leaves a non-empty English string untranslated as empty',
      () {
    for (final locale in AppLocale.values) {
      for (final entry in kStringsEn.entries) {
        if (entry.value.isEmpty) continue;
        expect(
          tables[locale]![entry.key],
          isNotEmpty,
          reason: '$locale is missing/empty for "${entry.key}"',
        );
      }
    }
  });

  test('Strings.t substitutes placeholders and falls back sanely', () {
    expect(Strings.t(AppLocale.it, 'ui.home.play'), 'GIOCA');
    expect(
      Strings.t(AppLocale.en, 'ui.home.best', {'n': '12'}),
      'BEST: LEVEL 12',
    );
    // Totally unknown key: falls back to the key itself, never throws.
    expect(Strings.t(AppLocale.de, 'does.not.exist'), 'does.not.exist');
  });

  test('spell_count word/letter/digit data is complete in every locale', () {
    for (final locale in AppLocale.values) {
      final letters = kSpellCountLetters[locale]!;
      final digits = kSpellCountDigits[locale]!;
      expect(letters.keys.toSet(), digits.keys.toSet(),
          reason: '$locale spell_count word sets diverge');
      expect(letters.length, 8, reason: '$locale needs exactly 8 words');
      for (final word in letters.keys) {
        expect(letters[word], greaterThan(0),
            reason: '$locale "$word" has a non-positive letter count');
        expect(digits[word], greaterThan(0),
            reason: '$locale "$word" has a non-positive digit value');
      }
    }
  });

  test('word.opposite pairs are two non-empty halves in every locale', () {
    for (final locale in AppLocale.values) {
      for (var i = 0; i < 6; i++) {
        final parts = Strings.t(locale, 'word.opposite.pair.$i').split('|');
        expect(parts.length, 2,
            reason: '$locale pair $i is not "A|B"-shaped');
        expect(parts[0], isNotEmpty);
        expect(parts[1], isNotEmpty);
      }
    }
  });

  test('every challenge instruction stays under 8 words in every language',
      () {
    // Mirrors the English-only check in challenge_templates_test.dart, but
    // across all six locales — the design rule (Game Design Pillars) applies
    // to every player, not just English ones. Caught a real French overflow
    // (padded guillemets) during the initial localization pass.
    for (final locale in AppLocale.values) {
      for (final template in kChallengeTemplates) {
        final params = ChallengeParams(
          level: template.minLevel,
          rng: Random(7),
          speed: 1.0,
          locale: locale,
        );
        final instruction = template.build(params).view.instruction.trim();
        if (instruction.isEmpty) continue; // e.g. no_instruction, by design
        final wordCount = instruction.split(RegExp(r'\s+')).length;
        expect(
          wordCount,
          lessThanOrEqualTo(8),
          reason: '$locale ${template.id}: "$instruction" is $wordCount words',
        );
      }
    }
  });

  testWidgets('the home screen renders in the language SettingsManager picks',
      (tester) async {
    SharedPreferences.setMockInitialValues({'ays.locale': 'it'});
    final services = await AppServices.boot();
    await tester.pumpWidget(AreYouStupidApp(services: services));
    await tester.pumpAndSettle();

    expect(find.text('MA SEI'), findsOneWidget);
    expect(find.text('SCEMO?'), findsOneWidget);
    expect(find.text('GIOCA'), findsOneWidget);
    expect(find.text('IMPOSTAZIONI'), findsOneWidget);
    expect(find.text('PLAY'), findsNothing);
  });
}
