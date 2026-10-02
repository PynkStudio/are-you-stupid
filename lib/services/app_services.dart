import 'package:flutter/widgets.dart';

import 'ads/ad_manager.dart';
import 'ads/ad_provider.dart';
import 'ads/mock_ad_provider.dart';
import 'haptic_manager.dart';
import 'multiplayer_profile.dart';
import 'purchases/mock_purchase_provider.dart';
import 'purchases/purchase_manager.dart';
import 'purchases/purchase_provider.dart';
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
    required this.multiplayerProfile,
    AdProvider? adProvider,
    PurchaseProvider? purchaseProvider,
  })  : sound = SoundManager(settings),
        haptics = HapticManager(settings),
        share = const ShareManager(),
        purchases = PurchaseManager(
          provider: purchaseProvider ?? MockPurchaseProvider(),
          settings: settings,
        ),
        ads = AdManager(
          provider: adProvider ?? MockAdProvider(),
          scores: scores,
          settings: settings,
        );

  final SettingsManager settings;
  final ScoreManager scores;
  final MultiplayerProfileManager multiplayerProfile;
  final SoundManager sound;
  final HapticManager haptics;
  final ShareManager share;
  final AdManager ads;
  final PurchaseManager purchases;

  static Future<AppServices> boot({
    AdProvider? adProvider,
    PurchaseProvider? purchaseProvider,
  }) async {
    final settings = await SettingsManager.load();
    final scores = await ScoreManager.load();
    final multiplayerProfile = await MultiplayerProfileManager.load();
    final services = AppServices(
      settings: settings,
      scores: scores,
      multiplayerProfile: multiplayerProfile,
      adProvider: adProvider,
      purchaseProvider: purchaseProvider,
    );
    // Purchases only read the store — never block the splash on a slow or
    // unreachable StoreKit/Play Billing. Settings retries the product later.
    await services.purchases
        .initialize()
        .timeout(const Duration(seconds: 4), onTimeout: () {});
    // Ads are *not* started here: consent (UMP) and the iOS ATT prompt are
    // native UI and must appear over a real, active screen — see
    // [startAds] and `main.dart`.
    return services;
  }

  /// Gathers ad consent and starts the ads SDK. Called once the first real
  /// screen is on display; never awaited by gameplay (no ad is ever needed
  /// to play).
  Future<void> startAds() => ads.initialize();

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
