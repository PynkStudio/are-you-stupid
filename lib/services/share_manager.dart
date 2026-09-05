import 'dart:ui';

import 'package:share_plus/share_plus.dart';

/// Builds the share text and hands it to the OS sheet.
/// No account, no backend, no tracking.
class ShareManager {
  const ShareManager();

  /// Fill this in when the app is live on the stores.
  static const storeUrl = '';

  static String resultText(int level, {int? best}) {
    final buffer = StringBuffer()
      ..writeln('I reached Level $level in ARE YOU STUPID?')
      ..writeln('Can you beat me?');
    if (best != null && best > level) buffer.writeln('(my best: Level $best)');
    if (storeUrl.isNotEmpty) buffer.writeln(storeUrl);
    return buffer.toString().trim();
  }

  Future<void> shareResult(
    int level, {
    int? best,
    Rect? origin,
  }) async {
    await SharePlus.instance.share(
      ShareParams(
        text: resultText(level, best: best),
        subject: 'ARE YOU STUPID?',
        sharePositionOrigin: origin,
      ),
    );
  }
}
