import 'dart:async';
import 'dart:io' show Platform;

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_provider.dart';
import 'ad_unit_ids.dart';

/// Real ads via the Google Mobile Ads SDK (AdMob).
///
/// Every failure mode — no network, no fill, load error — just leaves
/// [isReady] false and [show] returning false. Nothing here ever throws or
/// shows an error to the player: no ad is exactly the same as "declined".
class AdMobAdProvider implements AdProvider {
  InterstitialAd? _interstitial;
  RewardedAd? _rewarded;
  bool _loadingInterstitial = false;
  bool _loadingRewarded = false;

  @override
  Future<void> initialize() async {
    if (Platform.isIOS) {
      final status = await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status == TrackingStatus.notDetermined) {
        await AppTrackingTransparency.requestTrackingAuthorization();
      }
    }
    await MobileAds.instance.initialize();
  }

  @override
  bool isReady(AdPlacement placement) => switch (placement) {
        AdPlacement.interstitial => _interstitial != null,
        AdPlacement.rewardedContinue ||
        AdPlacement.rewardedDoubleXp =>
          _rewarded != null,
      };

  @override
  Future<void> preload(AdPlacement placement) => switch (placement) {
        AdPlacement.interstitial => _loadInterstitial(),
        AdPlacement.rewardedContinue ||
        AdPlacement.rewardedDoubleXp =>
          _loadRewarded(),
      };

  Future<void> _loadInterstitial() async {
    if (_interstitial != null || _loadingInterstitial) return;
    _loadingInterstitial = true;
    await InterstitialAd.load(
      adUnitId: AdUnitIds.forPlacement(AdPlacement.interstitial),
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _loadingInterstitial = false;
          _interstitial = ad;
        },
        onAdFailedToLoad: (_) => _loadingInterstitial = false,
      ),
    );
  }

  Future<void> _loadRewarded() async {
    if (_rewarded != null || _loadingRewarded) return;
    _loadingRewarded = true;
    await RewardedAd.load(
      adUnitId: AdUnitIds.forPlacement(AdPlacement.rewardedContinue),
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _loadingRewarded = false;
          _rewarded = ad;
        },
        onAdFailedToLoad: (_) => _loadingRewarded = false,
      ),
    );
  }

  @override
  Future<bool> show(BuildContext context, AdPlacement placement) =>
      switch (placement) {
        AdPlacement.interstitial => _showInterstitial(),
        AdPlacement.rewardedContinue ||
        AdPlacement.rewardedDoubleXp =>
          _showRewarded(),
      };

  Future<bool> _showInterstitial() async {
    final ad = _interstitial;
    if (ad == null) return false;
    _interstitial = null;

    final result = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        if (!result.isCompleted) result.complete(true);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        if (!result.isCompleted) result.complete(false);
      },
    );
    await ad.show();
    return result.future;
  }

  Future<bool> _showRewarded() async {
    final ad = _rewarded;
    if (ad == null) return false;
    _rewarded = null;

    final result = Completer<bool>();
    var earned = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        if (!result.isCompleted) result.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        if (!result.isCompleted) result.complete(false);
      },
    );
    await ad.show(onUserEarnedReward: (_, _) => earned = true);
    return result.future;
  }
}
