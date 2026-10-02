import 'package:are_you_stupid/services/ads/ad_manager.dart';
import 'package:are_you_stupid/services/ads/ad_provider.dart';
import 'package:are_you_stupid/services/score_manager.dart';
import 'package:are_you_stupid/services/settings_manager.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A provider that never has a fill, as if the device were offline.
class _NeverReadyAdProvider implements AdProvider {
  @override
  Future<void> initialize() async {}

  @override
  bool get privacyOptionsRequired => false;

  @override
  Future<void> showPrivacyOptions() async {}

  @override
  Future<void> preload(AdPlacement placement) async {}

  @override
  bool isReady(AdPlacement placement) => false;

  @override
  Future<bool> show(BuildContext context, AdPlacement placement) async =>
      false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('rewarded continue is not offered when no ad is ready (offline)',
      () async {
    SharedPreferences.setMockInitialValues({});
    final scores = await ScoreManager.load();
    final settings = await SettingsManager.load();
    final ads = AdManager(
      provider: _NeverReadyAdProvider(),
      scores: scores,
      settings: settings,
    );

    expect(ads.isRewardedContinueReady, isFalse);
  });

  testWidgets('remove-ads purchase grants rewarded continue offline, for free',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final scores = await ScoreManager.load();
    final settings = await SettingsManager.load();
    final ads = AdManager(
      provider: _NeverReadyAdProvider(),
      scores: scores,
      settings: settings,
    );
    await settings.setNoAdsPurchased(true);

    expect(ads.isRewardedContinueReady, isTrue);

    late BuildContext capturedContext;
    await tester.pumpWidget(Builder(builder: (context) {
      capturedContext = context;
      return const SizedBox();
    }));

    expect(await ads.showRewardedContinue(capturedContext), isTrue);
  });

  test('remove-ads purchase suppresses the interstitial', () async {
    SharedPreferences.setMockInitialValues({'ays.runsSinceAd': 3});
    final scores = await ScoreManager.load();
    final settings = await SettingsManager.load();
    final ads = AdManager(
      provider: _NeverReadyAdProvider(),
      scores: scores,
      settings: settings,
    );

    expect(ads.shouldShowInterstitial, isTrue);
    await settings.setNoAdsPurchased(true);
    expect(ads.shouldShowInterstitial, isFalse);
  });
}
