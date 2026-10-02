import 'package:flutter/widgets.dart';

/// Ad placements the game knows about.
enum AdPlacement { interstitial, rewardedContinue, rewardedDoubleXp }

/// Swap this implementation to plug in AdMob / AppLovin / whatever.
/// Nothing else in the app talks to an ad SDK.
abstract class AdProvider {
  /// Gathers privacy consent (GDPR/UMP, then ATT on iOS) and starts the SDK.
  /// May show native consent UI, so it must run once a real screen is up —
  /// never during the splash. See docs/Product/Monetization and Ads.md.
  Future<void> initialize();

  /// True when the player must be offered a way to change their ad-privacy
  /// choices (EEA/UK users under the UMP rules). Settings shows a
  /// "privacy choices" row only then.
  bool get privacyOptionsRequired;

  /// Re-opens the consent form so the player can change their choices.
  Future<void> showPrivacyOptions();

  /// Warm up the next ad. Safe to call often.
  Future<void> preload(AdPlacement placement);

  /// True when an ad is loaded and ready to `show` right now. Offline (or any
  /// load failure) simply leaves this false — callers must check it before
  /// offering the player a button that depends on the ad.
  bool isReady(AdPlacement placement);

  /// Returns true when the ad was fully watched (rewarded) or dismissed
  /// normally (interstitial). False means "no ad, carry on".
  Future<bool> show(BuildContext context, AdPlacement placement);
}
