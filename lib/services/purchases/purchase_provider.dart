/// Product IDs as configured in App Store Connect / Google Play Console.
/// Both stores must use this exact identifier for the entry to resolve.
abstract final class IapProductIds {
  static const removeAds = 'ays_remove_ads';
}

enum PurchaseUpdateStatus { purchased, restored, pending, canceled, error }

class PurchaseUpdate {
  const PurchaseUpdate({required this.productId, required this.status});

  final String productId;
  final PurchaseUpdateStatus status;
}

/// Store-provided display info for a product — id, title and the
/// store-localized price string (already formatted with the user's
/// currency/symbol, e.g. "$2.99").
class PurchaseProduct {
  const PurchaseProduct({
    required this.id,
    required this.title,
    required this.price,
  });

  final String id;
  final String title;
  final String price;
}

/// Swap this implementation to plug in a different store abstraction.
/// Nothing else in the app talks to `in_app_purchase` directly.
abstract class PurchaseProvider {
  Future<void> initialize();

  /// False when the platform store is unreachable (or unsupported, like
  /// desktop dev builds) — callers must hide any buy/restore button rather
  /// than offer one that can't work, same rule as `AdProvider.isReady`.
  bool get isAvailable;

  /// Null until the store has resolved the product (or if it never does).
  PurchaseProduct? get removeAdsProduct;

  Stream<PurchaseUpdate> get purchaseUpdates;

  /// Re-queries the store for [removeAdsProduct] — called when Settings
  /// opens, so a product that failed to load at boot (offline, slow
  /// StoreKit) still shows up later in the session.
  Future<void> refreshProduct();

  Future<void> buyRemoveAds();

  Future<void> restorePurchases();
}
