import 'dart:math';

import '../i18n/app_locale.dart';
import '../i18n/strings.dart';

/// Short lines shown after a mistake. Mix of playful roasts and neutral ones —
/// the game teases, it never actually bullies. Every pool is translated (not
/// machine-translated word for word) per language in
/// `lib/i18n/strings_*.dart` under `roast.*` — see
/// `docs/Architecture/Localization.md`.
class Roasts {
  Roasts._();

  static const _spicyCount = 16;
  static const _neutralCount = 10;
  static const _lateCount = 4;
  static const _praiseCount = 6;

  static List<String> spicy(AppLocale locale) =>
      Strings.list(locale, 'roast.spicy', _spicyCount);

  static List<String> neutral(AppLocale locale) =>
      Strings.list(locale, 'roast.neutral', _neutralCount);

  static List<String> late(AppLocale locale) =>
      Strings.list(locale, 'roast.late', _lateCount);

  static List<String> praise(AppLocale locale) =>
      Strings.list(locale, 'roast.praise', _praiseCount);

  static final _rng = Random();

  /// ~55% neutral so the game stays playful instead of hostile.
  /// With [allowSpicy] off (Settings), only the neutral pool is used.
  static String forMistake({
    Random? rng,
    bool allowSpicy = true,
    AppLocale locale = AppLocale.en,
  }) {
    final r = rng ?? _rng;
    final pool =
        !allowSpicy || r.nextDouble() < 0.55 ? neutral(locale) : spicy(locale);
    return pool[r.nextInt(pool.length)];
  }

  static String gameOver({
    Random? rng,
    bool allowSpicy = true,
    AppLocale locale = AppLocale.en,
  }) {
    final r = rng ?? _rng;
    final pool =
        !allowSpicy || r.nextDouble() < 0.5 ? neutral(locale) : spicy(locale);
    return pool[r.nextInt(pool.length)];
  }

  static String pick(List<String> pool, [Random? rng]) {
    final r = rng ?? _rng;
    return pool[r.nextInt(pool.length)];
  }
}
