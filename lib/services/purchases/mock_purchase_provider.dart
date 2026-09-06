import 'dart:async';

import 'purchase_provider.dart';

/// A fake store for platforms `in_app_purchase` ships no native
/// implementation for (desktop dev builds) and for tests — mirrors
/// `MockAdProvider`'s role for ads. `buyRemoveAds`/`restorePurchases`
/// resolve immediately so the settings flow is exercisable without real
/// store credentials.
class MockPurchaseProvider implements PurchaseProvider {
  final _updates = StreamController<PurchaseUpdate>.broadcast();

  @override
  bool get isAvailable => true;

  @override
  PurchaseProduct? get removeAdsProduct => const PurchaseProduct(
        id: IapProductIds.removeAds,
        title: 'Remove Ads',
        price: '\$2.99',
      );

  @override
  Stream<PurchaseUpdate> get purchaseUpdates => _updates.stream;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> buyRemoveAds() async {
    _updates.add(const PurchaseUpdate(
      productId: IapProductIds.removeAds,
      status: PurchaseUpdateStatus.purchased,
    ));
  }

  @override
  Future<void> restorePurchases() async {
    _updates.add(const PurchaseUpdate(
      productId: IapProductIds.removeAds,
      status: PurchaseUpdateStatus.restored,
    ));
  }
}
