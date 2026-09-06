/// Supported app languages. Pure Dart: importable from `core/` and
/// `challenges/` without breaking the "no Flutter" rule.
library;

enum AppLocale {
  en,
  it,
  fr,
  es,
  pt,
  de;

  /// ISO 639-1 code, matches the device locale's `languageCode`.
  String get code => name;

  /// Name shown in the language picker, written in its own language.
  String get nativeName => switch (this) {
        AppLocale.en => 'English',
        AppLocale.it => 'Italiano',
        AppLocale.fr => 'Français',
        AppLocale.es => 'Español',
        AppLocale.pt => 'Português',
        AppLocale.de => 'Deutsch',
      };

  /// Resolves a raw language code (from a saved setting or the device) to a
  /// supported locale. Falls back to English for anything unsupported.
  static AppLocale fromCode(String? code) => AppLocale.values.firstWhere(
        (l) => l.code == code,
        orElse: () => AppLocale.en,
      );
}
