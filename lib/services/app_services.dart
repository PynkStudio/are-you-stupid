import 'package:flutter/widgets.dart';

import 'ads/ad_manager.dart';
import 'ads/ad_provider.dart';
import 'ads/mock_ad_provider.dart';
import 'haptic_manager.dart';
import 'score_manager.dart';
import 'settings_manager.dart';
import 'share_manager.dart';
import 'sound_manager.dart';

/// One bag of services, injected at the root. No global singletons, no DI
/// framework, no ceremony.
class AppServices {
  AppServices({
    required this.settings,
    required this.scores,
    AdProvider? adProvider,
  })  : sound = SoundManager(settings),
        haptics = HapticManager(settings),
        share = const ShareManager(),
        ads = AdManager(
          provider: adProvider ?? MockAdProvider(),
          scores: scores,
        );

  final SettingsManager settings;
  final ScoreManager scores;
  final SoundManager sound;
  final HapticManager haptics;
  final ShareManager share;
  final AdManager ads;

  static Future<AppServices> boot({AdProvider? adProvider}) async {
    final settings = await SettingsManager.load();
    final scores = await ScoreManager.load();
    final services = AppServices(
      settings: settings,
      scores: scores,
      adProvider: adProvider,
    );
    await services.ads.initialize();
    return services;
  }

  static AppServices of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<ServicesScope>();
    assert(scope != null, 'ServicesScope missing above this widget');
    return scope!.services;
  }
}

class ServicesScope extends InheritedWidget {
  const ServicesScope({
    super.key,
    required this.services,
    required super.child,
  });

  final AppServices services;

  @override
  bool updateShouldNotify(ServicesScope oldWidget) =>
      oldWidget.services != services;
}
