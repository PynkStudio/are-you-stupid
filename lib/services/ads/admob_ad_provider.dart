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

  /// False until consent allows ad requests (UMP `canRequestAds`). Every
  /// load is a no-op while false, so a player who declined in the EEA simply
  /// sees no ads (and no continue button, unless ads were removed).
  bool _canRequestAds = false;
  bool _sdkStarted = false;
  bool _privacyOptionsRequired = false;

  @override
  bool get privacyOptionsRequired => _privacyOptionsRequired;

  /// Google's required order: UMP consent first (GDPR/UK), then the iOS ATT
  /// prompt, then the SDK. Runs after the first real screen is up (see
  /// `main.dart`) — ATT requested while the app isn't active yet is silently
  /// dropped by iOS, which App Review flags as "ATT prompt not found".
  @override
  Future<void> initialize() async {
    await _updateConsentInfo();
    await _showConsentFormIfRequired();
    if (Platform.isIOS) await _requestTracking();
    await _startSdkIfAllowed();
  }

  /// Asks for ATT once, never blocking the ads SDK on the answer.
  ///
  /// Requested while the consent form is still animating away, iOS drops the
  /// prompt; `app_tracking_transparency` then waits for the *next*
  /// `didBecomeActive` to retry, so awaiting it unbounded left the SDK
  /// unstarted (no ads at all) until the player backgrounded the app. The
  /// short pause lets the form finish dismissing; the timeout lets ads start
  /// regardless, and the plugin still shows the prompt on the next resume.
  /// See docs/Meta/Decision Log.md.
  Future<void> _requestTracking() async {
    try {
      final status = await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status != TrackingStatus.notDetermined) return;
      await Future<void>.delayed(const Duration(milliseconds: 900));
      await AppTrackingTransparency.requestTrackingAuthorization().timeout(
        const Duration(seconds: 20),
        onTimeout: () => TrackingStatus.notDetermined,
      );
    } catch (_) {
      // A failed ATT call only means non-personalised ads.
    }
  }

  @override
  Future<void> showPrivacyOptions() async {
    final done = Completer<void>();
    await ConsentForm.showPrivacyOptionsForm((_) {
      if (!done.isCompleted) done.complete();
    });
    await done.future;
    await _refreshPrivacyStatus();
    await _startSdkIfAllowed();
  }

  Future<void> _updateConsentInfo() async {
    final done = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () {
        if (!done.isCompleted) done.complete();
      },
      (_) {
        // Offline or misconfigured: UMP falls back to the last stored
        // consent, which `canRequestAds` below still honours.
        if (!done.isCompleted) done.complete();
      },
    );
    await done.future.timeout(const Duration(seconds: 10), onTimeout: () {});
  }

  Future<void> _showConsentFormIfRequired() async {
    try {
      await ConsentForm.loadAndShowConsentFormIfRequired((_) {});
    } catch (_) {
      // No form available (e.g. offline) — same fallback as above.
    }
    await _refreshPrivacyStatus();
  }

  Future<void> _refreshPrivacyStatus() async {
    try {
      _privacyOptionsRequired = await ConsentInformation.instance
              .getPrivacyOptionsRequirementStatus() ==
          PrivacyOptionsRequirementStatus.required;
      _canRequestAds = await ConsentInformation.instance.canRequestAds();
    } catch (_) {
      _canRequestAds = false;
    }
  }

  Future<void> _startSdkIfAllowed() async {
    if (!_canRequestAds || _sdkStarted) return;
    _sdkStarted = true;
    await MobileAds.instance.initialize();
    await _loadInterstitial();
    await _loadRewarded();
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
    if (!_sdkStarted || _interstitial != null || _loadingInterstitial) return;
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
    if (!_sdkStarted || _rewarded != null || _loadingRewarded) return;
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
