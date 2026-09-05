import 'package:flutter/widgets.dart';

import '../score_manager.dart';
import 'ad_provider.dart';

/// Ad *policy* lives here, not in the UI:
/// - never on launch, never mid-gameplay;
/// - interstitial roughly every 3-4 finished runs;
/// - one rewarded continue per run.
class AdManager {
  AdManager({required AdProvider provider, required ScoreManager scores})
      : _provider = provider,
        _scores = scores;

  final AdProvider _provider;
  final ScoreManager _scores;


  static const _runsBetweenInterstitials = 3;

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await _provider.initialize();
    await _provider.preload(AdPlacement.interstitial);
    await _provider.preload(AdPlacement.rewardedContinue);
  }

  bool get shouldShowInterstitial =>
      _scores.runsSinceAd >= _runsBetweenInterstitials;

  /// False when offline (or no fill) — callers must hide the "continue"
  /// button rather than offer an ad that can't play.
  bool get isRewardedContinueReady =>
      _provider.isReady(AdPlacement.rewardedContinue);

  /// Called on the Game Over screen, after the score is recorded.
  Future<void> maybeShowInterstitial(BuildContext context) async {
    if (!shouldShowInterstitial) return;
    final shown = await _provider.show(context, AdPlacement.interstitial);
    if (shown) await _scores.markInterstitialShown();
    await _provider.preload(AdPlacement.interstitial);
  }

  /// Returns true when the player earned the continue.
  Future<bool> showRewardedContinue(BuildContext context) async {
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
