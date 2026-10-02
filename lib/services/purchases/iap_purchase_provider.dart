import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

import 'purchase_provider.dart';

/// Wraps the `in_app_purchase` plugin for the single "remove ads"
/// non-consumable. Android/iOS only — see `main.dart`, which falls back to
/// [MockPurchaseProvider] everywhere else, the same split as `AdProvider`.
class IapPurchaseProvider implements PurchaseProvider {
  final InAppPurchase _iap = InAppPurchase.instance;
  final _updates = StreamController<PurchaseUpdate>.broadcast();

  StreamSubscription<List<PurchaseDetails>>? _subscription;
  ProductDetails? _details;
  bool _available = false;

  @override
  bool get isAvailable => _available;

  @override
  PurchaseProduct? get removeAdsProduct {
    final details = _details;
    if (details == null) return null;
    return PurchaseProduct(
      id: details.id,
      title: details.title,
      price: details.price,
    );
  }

  @override
  Stream<PurchaseUpdate> get purchaseUpdates => _updates.stream;

  @override
  Future<void> initialize() async {
    _subscription = _iap.purchaseStream.listen(_onPurchaseDetails);
    await refreshProduct();
  }

  @override
  Future<void> refreshProduct() async {
    if (_details != null) return;
    try {
      _available = await _iap.isAvailable();
      if (!_available) return;
      final response =
          await _iap.queryProductDetails({IapProductIds.removeAds});
      if (response.productDetails.isNotEmpty) {
        _details = response.productDetails.first;
      }
    } catch (_) {
      // Store unreachable: leave the product unresolved, retry next time.
    }
  }

  @override
  Future<void> buyRemoveAds() async {
    final details = _details;
    if (details == null) throw StateError('remove-ads product not loaded');
    final started = await _iap.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: details),
    );
    if (!started) throw StateError('store refused to start the purchase');
  }

  @override
  Future<void> restorePurchases() => _iap.restorePurchases();

  Future<void> _onPurchaseDetails(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.productID == IapProductIds.removeAds) {
        _updates.add(PurchaseUpdate(
          productId: purchase.productID,
          status: switch (purchase.status) {
            PurchaseStatus.purchased => PurchaseUpdateStatus.purchased,
            PurchaseStatus.restored => PurchaseUpdateStatus.restored,
            PurchaseStatus.pending => PurchaseUpdateStatus.pending,
            PurchaseStatus.canceled => PurchaseUpdateStatus.canceled,
            PurchaseStatus.error => PurchaseUpdateStatus.error,
          },
        ));
      }
      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }
  }

  void dispose() {
    _subscription?.cancel();
    _updates.close();
  }
}
