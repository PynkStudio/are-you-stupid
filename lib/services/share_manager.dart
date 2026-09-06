import 'dart:ui';

import 'package:share_plus/share_plus.dart';

import '../i18n/app_locale.dart';
import '../i18n/strings.dart';

/// Builds the share text and hands it to the OS sheet.
/// No account, no backend, no tracking.
class ShareManager {
  const ShareManager();

  /// Fill this in when the app is live on the stores.
  static const storeUrl = '';

  static String resultText(int level, {int? best, AppLocale locale = AppLocale.en}) {
    final buffer = StringBuffer()
      ..writeln(Strings.t(locale, 'share.line1', {'level': '$level'}))
      ..writeln(Strings.t(locale, 'share.line2'));
    if (best != null && best > level) {
      buffer.writeln(Strings.t(locale, 'share.best', {'best': '$best'}));
    }
    if (storeUrl.isNotEmpty) buffer.writeln(storeUrl);
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
}
