import 'dart:io' show Platform;

import 'ad_provider.dart';

/// AdMob ad unit IDs, one pair per platform.
///
/// Real IDs from the "Are You Stupid?" AdMob account (publisher
/// ca-app-pub-6747636382023443), one app per platform. If you ever need to
/// point at a fresh AdMob property, update these together with the app IDs
/// in ios/Runner/Info.plist and android/app/src/main/AndroidManifest.xml —
/// see docs/Product/Monetization and Ads.md.
abstract final class AdUnitIds {
  static String forPlacement(AdPlacement placement) {
    switch (placement) {
      case AdPlacement.interstitial:
        return Platform.isIOS
            ? 'ca-app-pub-6747636382023443/6256938037'
            : 'ca-app-pub-6747636382023443/7277893168';
      case AdPlacement.rewardedContinue:
      case AdPlacement.rewardedDoubleXp:
        return Platform.isIOS
            ? 'ca-app-pub-6747636382023443/8479294195'
            : 'ca-app-pub-6747636382023443/7166212524';
    }
  }
}
