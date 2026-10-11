import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:are_you_stupid/services/purchases/mock_purchase_provider.dart';
import 'package:are_you_stupid/services/purchases/purchase_manager.dart';
import 'package:are_you_stupid/services/settings_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Party Pack unlocks capacity without removing ads', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = await SettingsManager.load();
    final purchases = PurchaseManager(
      provider: MockPurchaseProvider(),
      settings: settings,
    );
    await purchases.initialize();

    await purchases.buyPartyPack();
    await Future<void>.delayed(Duration.zero);

    expect(settings.partyPackPurchased, isTrue);
    expect(settings.partyCapacityUnlocked, isTrue);
    expect(settings.adsRemoved, isFalse);
    purchases.dispose();
  });

  test('Party Bundle unlocks capacity and removes ads', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = await SettingsManager.load();
    final purchases = PurchaseManager(
      provider: MockPurchaseProvider(),
      settings: settings,
    );
    await purchases.initialize();

    await purchases.buyPartyBundle();
    await Future<void>.delayed(Duration.zero);

    expect(settings.partyBundlePurchased, isTrue);
    expect(settings.partyCapacityUnlocked, isTrue);
    expect(settings.adsRemoved, isTrue);
    purchases.dispose();
  });
}
