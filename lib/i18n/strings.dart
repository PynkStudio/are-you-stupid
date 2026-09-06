/// Central lookup for every translatable string in the app.
///
/// Pure Dart, no Flutter import, so `core/` and `challenges/` can use it
/// directly. Each locale's content lives in its own flat `Map<String,String>`
/// (`strings_en.dart`, `strings_it.dart`, ...) keyed by dotted strings such as
/// `challenge.tap_color.instruction` or `ui.home.play`. Missing keys fall
/// back to English, then to the key itself, so a half-translated locale never
/// crashes the app.
library;

import 'app_locale.dart';
import 'strings_de.dart';
import 'strings_en.dart';
import 'strings_es.dart';
import 'strings_fr.dart';
import 'strings_it.dart';
import 'strings_pt.dart';

class Strings {
  Strings._();

  static const Map<AppLocale, Map<String, String>> _tables = {
    AppLocale.en: kStringsEn,
    AppLocale.it: kStringsIt,
    AppLocale.fr: kStringsFr,
    AppLocale.es: kStringsEs,
    AppLocale.pt: kStringsPt,
    AppLocale.de: kStringsDe,
  };

  /// Looks up [key] for [locale], substitutes `{name}` placeholders from
  /// [args], and falls back to English (then the raw key) if missing.
  static String t(AppLocale locale, String key, [Map<String, String>? args]) {
    final raw = _tables[locale]?[key] ?? kStringsEn[key] ?? key;
    if (args == null || args.isEmpty) return raw;
    var result = raw;
    for (final entry in args.entries) {
      result = result.replaceAll('{${entry.key}}', entry.value);
    }
    return result;
  }

  /// Reads an indexed pool `'$prefix.0'`, `'$prefix.1'`, ... of [count]
  /// entries. Used for the roast/viral-prompt/word-content pools.
  static List<String> list(AppLocale locale, String prefix, int count) => [
        for (var i = 0; i < count; i++) t(locale, '$prefix.$i'),
      ];
}
