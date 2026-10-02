import 'dart:ui';

import 'package:share_plus/share_plus.dart';

import '../i18n/app_locale.dart';
import '../i18n/strings.dart';

/// Builds the share text and hands it to the OS sheet.
/// No account, no backend, no tracking.
class ShareManager {
  const ShareManager();

  /// The game's landing page, one per language family — the same pages
  /// Settings links as "ABOUT THE GAME". A web page instead of a store link
  /// on purpose: a shared result is read on any phone (an iPhone result sent
  /// to an Android friend and vice versa), and the page links both stores.
  static const _landingIt = 'https://pynkstudio.eu/it/lavori/are-you-stupid';
  static const _landingEn = '$_landingIt/en';

  static String landingUrlFor(AppLocale locale) =>
      locale == AppLocale.it ? _landingIt : _landingEn;

  static String resultText(int level, {int? best, AppLocale locale = AppLocale.en}) {
    final buffer = StringBuffer()
      ..writeln(Strings.t(locale, 'share.line1', {'level': '$level'}))
      ..writeln(Strings.t(locale, 'share.line2'));
    if (best != null && best > level) {
      buffer.writeln(Strings.t(locale, 'share.best', {'best': '$best'}));
    }
    buffer.writeln(landingUrlFor(locale));
    return buffer.toString().trim();
  }

  Future<void> shareResult(
    int level, {
    int? best,
    Rect? origin,
    AppLocale locale = AppLocale.en,
  }) async {
    await SharePlus.instance.share(
      ShareParams(
        text: resultText(level, best: best, locale: locale),
        subject: Strings.t(locale, 'app.title'),
        sharePositionOrigin: origin,
      ),
    );
  }

  /// Result text for a finished multiplayer match ([[Multiplayer Product]]
  /// "Sharing").
  static String multiplayerResultText(
    String winnerName, {
    AppLocale locale = AppLocale.en,
  }) {
    final buffer = StringBuffer()
      ..writeln(Strings.t(locale, 'ui.mp.share.line1', {'name': winnerName}))
      ..writeln(Strings.t(locale, 'ui.mp.share.line2'));
    buffer.writeln(landingUrlFor(locale));
    return buffer.toString().trim();
  }

  Future<void> shareMultiplayerResult(
    String winnerName, {
    Rect? origin,
    AppLocale locale = AppLocale.en,
  }) async {
    await SharePlus.instance.share(
      ShareParams(
        text: multiplayerResultText(winnerName, locale: locale),
        subject: Strings.t(locale, 'app.title'),
        sharePositionOrigin: origin,
      ),
    );
  }
}
