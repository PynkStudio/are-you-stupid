import 'package:are_you_stupid/services/ads/ad_manager.dart';
import 'package:are_you_stupid/services/ads/ad_provider.dart';
import 'package:are_you_stupid/services/score_manager.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A provider that never has a fill, as if the device were offline.
class _NeverReadyAdProvider implements AdProvider {
  @override
  Future<void> initialize() async {}

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
    final ads = AdManager(provider: _NeverReadyAdProvider(), scores: scores);

    expect(ads.isRewardedContinueReady, isFalse);
  });
}
