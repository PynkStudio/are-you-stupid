import 'dart:async';

import 'package:flutter/foundation.dart';

import '../settings_manager.dart';
import 'purchase_provider.dart';

/// A one-shot result surfaced to the UI after a buy/restore call settles, so
/// the settings screen can show a message. Cleared by [PurchaseManager.clearFeedback].
enum PurchaseFeedback { purchased, restored, nothingToRestore, error }

/// Purchase *policy* lives here, not in the UI: buy/restore Remove Ads and
/// Party Pack and Party Bundle, then mirror store-confirmed entitlements into
/// SettingsManager.
class PurchaseManager extends ChangeNotifier {
  PurchaseManager({
    required PurchaseProvider provider,
    required SettingsManager settings,
  }) : _provider = provider,
       _settings = settings;

  final PurchaseProvider _provider;
  final SettingsManager _settings;
  StreamSubscription<PurchaseUpdate>? _subscription;
  Timer? _restoreTimeout;

  bool _initialized = false;
  bool busy = false;
  PurchaseFeedback? feedback;

  bool get isPurchased => _settings.adsRemoved;
  bool get isPartyPackPurchased => _settings.partyPackPurchased;
  bool get isPartyBundlePurchased => _settings.partyBundlePurchased;
  bool get storeAvailable => _provider.isAvailable;
  PurchaseProduct? get product => _provider.removeAdsProduct;
  PurchaseProduct? get partyPackProduct => _provider.partyPackProduct;
  PurchaseProduct? get partyBundleProduct => _provider.partyBundleProduct;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    _subscription = _provider.purchaseUpdates.listen(_onUpdate);
    try {
      await _provider.initialize();
    } catch (_) {
      // Store unreachable at boot: Settings retries via [refreshProduct].
    }
    notifyListeners();
  }

  /// Retries loading the product (see [PurchaseProvider.refreshProduct]).
  Future<void> refreshProduct() async {
    await _provider.refreshProduct();
    notifyListeners();
  }

  Future<void> buyPartyPack() async {
    if (isPartyPackPurchased ||
        busy ||
        !storeAvailable ||
        partyPackProduct == null) {
      return;
    }
    busy = true;
    notifyListeners();
    try {
      await _provider.buyPartyPack();
    } catch (_) {
      _settle(PurchaseFeedback.error);
    }
  }

  Future<void> buyRemoveAds() async {
    if (isPurchased || busy || !storeAvailable || product == null) return;
    busy = true;
    notifyListeners();
    try {
      await _provider.buyRemoveAds();
    } catch (_) {
      // A thrown store call never produces a purchase update, so without
      // this the buy button would stay disabled for the whole session.
      _settle(PurchaseFeedback.error);
    }
  }

  Future<void> buyPartyBundle() async {
    if (isPartyBundlePurchased ||
        busy ||
        !storeAvailable ||
        partyBundleProduct == null) {
      return;
    }
    busy = true;
    notifyListeners();
    try {
      await _provider.buyPartyBundle();
    } catch (_) {
      _settle(PurchaseFeedback.error);
    }
  }

  Future<void> restorePurchases() async {
    if (busy || !storeAvailable) return;
    busy = true;
    notifyListeners();
    try {
      await _provider.restorePurchases();
    } catch (_) {
      _settle(PurchaseFeedback.error);
      return;
    }
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

  void _settle(PurchaseFeedback value) {
    busy = false;
    feedback = value;
    notifyListeners();
  }

  void clearFeedback() {
    feedback = null;
  }

  Future<void> _onUpdate(PurchaseUpdate update) async {
    if (update.productId != IapProductIds.removeAds &&
        update.productId != IapProductIds.partyPack &&
        update.productId != IapProductIds.partyBundle) {
      return;
    }
    _restoreTimeout?.cancel();
    switch (update.status) {
      case PurchaseUpdateStatus.purchased:
        if (update.productId == IapProductIds.partyPack) {
          await _settings.setPartyPackPurchased(true);
        } else if (update.productId == IapProductIds.partyBundle) {
          await _settings.setPartyBundlePurchased(true);
        } else {
          await _settings.setNoAdsPurchased(true);
        }
        feedback = PurchaseFeedback.purchased;
        busy = false;
      case PurchaseUpdateStatus.restored:
        if (update.productId == IapProductIds.partyPack) {
          await _settings.setPartyPackPurchased(true);
        } else if (update.productId == IapProductIds.partyBundle) {
          await _settings.setPartyBundlePurchased(true);
        } else {
          await _settings.setNoAdsPurchased(true);
        }
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
