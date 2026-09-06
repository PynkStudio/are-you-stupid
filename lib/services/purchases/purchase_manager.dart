import 'dart:async';

import 'package:flutter/foundation.dart';

import '../settings_manager.dart';
import 'purchase_provider.dart';

/// A one-shot result surfaced to the UI after a buy/restore call settles, so
/// the settings screen can show a message. Cleared by [PurchaseManager.clearFeedback].
enum PurchaseFeedback { purchased, restored, nothingToRestore, error }

/// Purchase *policy* lives here, not in the UI: buy/restore the single
/// "remove ads" non-consumable and mirror the result into
/// `SettingsManager.noAdsPurchased`, which is the flag `AdManager` actually
/// gates on. See docs/Product/Monetization and Ads.md.
class PurchaseManager extends ChangeNotifier {
  PurchaseManager({required PurchaseProvider provider, required SettingsManager settings})
      : _provider = provider,
        _settings = settings;

  final PurchaseProvider _provider;
  final SettingsManager _settings;
  StreamSubscription<PurchaseUpdate>? _subscription;
  Timer? _restoreTimeout;

  bool _initialized = false;
  bool busy = false;
  PurchaseFeedback? feedback;

  bool get isPurchased => _settings.noAdsPurchased;
  bool get storeAvailable => _provider.isAvailable;
  PurchaseProduct? get product => _provider.removeAdsProduct;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    _subscription = _provider.purchaseUpdates.listen(_onUpdate);
    await _provider.initialize();
  }

  Future<void> buyRemoveAds() async {
    if (isPurchased || busy || !storeAvailable || product == null) return;
    busy = true;
    notifyListeners();
    await _provider.buyRemoveAds();
  }

  Future<void> restorePurchases() async {
    if (busy || !storeAvailable) return;
    busy = true;
    notifyListeners();
    await _provider.restorePurchases();
    // Some stores stay silent on `restorePurchases()` when there is nothing
    // to restore — fall back to "not found" if no update ever arrives.
    _restoreTimeout?.cancel();
    _restoreTimeout = Timer(const Duration(seconds: 6), () {
      if (!busy) return;
      busy = false;
      feedback = PurchaseFeedback.nothingToRestore;
      notifyListeners();
    });
  }

  void clearFeedback() {
    feedback = null;
  }

  void _onUpdate(PurchaseUpdate update) {
    if (update.productId != IapProductIds.removeAds) return;
    _restoreTimeout?.cancel();
    switch (update.status) {
      case PurchaseUpdateStatus.purchased:
        _settings.setNoAdsPurchased(true);
        feedback = PurchaseFeedback.purchased;
        busy = false;
      case PurchaseUpdateStatus.restored:
        _settings.setNoAdsPurchased(true);
        feedback = PurchaseFeedback.restored;
        busy = false;
      case PurchaseUpdateStatus.canceled:
        busy = false;
      case PurchaseUpdateStatus.error:
        feedback = PurchaseFeedback.error;
        busy = false;
      case PurchaseUpdateStatus.pending:
        return;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _restoreTimeout?.cancel();
    _subscription?.cancel();
    super.dispose();
  }
}
