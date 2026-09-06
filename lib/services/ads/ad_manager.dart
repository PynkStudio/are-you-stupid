import 'package:flutter/widgets.dart';

import '../score_manager.dart';
import '../settings_manager.dart';
import 'ad_provider.dart';

/// Ad *policy* lives here, not in the UI:
/// - never on launch, never mid-gameplay;
/// - interstitial roughly every 3-4 finished runs;
/// - one rewarded continue per run;
/// - none of the above once `SettingsManager.noAdsPurchased` is set.
class AdManager {
  AdManager({
    required AdProvider provider,
    required ScoreManager scores,
    required SettingsManager settings,
  })  : _provider = provider,
        _scores = scores,
        _settings = settings;

  final AdProvider _provider;
  final ScoreManager _scores;
  final SettingsManager _settings;

  static const _runsBetweenInterstitials = 3;

  bool _initialized = false;

  bool get _adsRemoved => _settings.noAdsPurchased;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await _provider.initialize();
    await _provider.preload(AdPlacement.interstitial);
    await _provider.preload(AdPlacement.rewardedContinue);
  }

  bool get shouldShowInterstitial =>
      !_adsRemoved && _scores.runsSinceAd >= _runsBetweenInterstitials;

  /// False when offline (or no fill) — callers must hide the "continue"
  /// button rather than offer an ad that can't play. Once ads are removed,
  /// continue is granted for free and this is always true, offline included.
  bool get isRewardedContinueReady =>
      _adsRemoved || _provider.isReady(AdPlacement.rewardedContinue);

  /// Called on the Game Over screen, after the score is recorded.
  Future<void> maybeShowInterstitial(BuildContext context) async {
    if (!shouldShowInterstitial) return;
    final shown = await _provider.show(context, AdPlacement.interstitial);
    if (shown) await _scores.markInterstitialShown();
    await _provider.preload(AdPlacement.interstitial);
  }

  /// Returns true when the player earned the continue.
  Future<bool> showRewardedContinue(BuildContext context) async {
    if (_adsRemoved) return true;
    final ok = await _provider.show(context, AdPlacement.rewardedContinue);
    await _provider.preload(AdPlacement.rewardedContinue);
    return ok;
  }

  Future<bool> showRewardedDoubleXp(BuildContext context) async {
    final ok = await _provider.show(context, AdPlacement.rewardedDoubleXp);
    await _provider.preload(AdPlacement.rewardedDoubleXp);
    return ok;
  }
}
