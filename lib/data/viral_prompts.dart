import 'dart:math';

import '../i18n/app_locale.dart';
import '../i18n/strings.dart';

/// Occasional nudges to challenge a friend. Shown rarely on purpose.
/// Translated per language in `lib/i18n/strings_*.dart` under `viral.*`.
class ViralPrompts {
  ViralPrompts._();

  static const _count = 6;

  static List<String> lines(AppLocale locale) =>
      Strings.list(locale, 'viral', _count);

  static final _rng = Random();

  static String random(AppLocale locale, [Random? rng]) {
    final r = rng ?? _rng;
    final pool = lines(locale);
    return pool[r.nextInt(pool.length)];
  }
}
