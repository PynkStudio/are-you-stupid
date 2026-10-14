import 'package:flutter/widgets.dart';

import 'ad_provider.dart';

/// The shipped Mac build has no ad SDK (google_mobile_ads is Android/iOS
/// only) and must never show the mock overlay to real players: every
/// placement is simply "no ad". Pair it with `AppServices(adFree: true)` so
/// the rewarded continue is granted for free instead of disappearing.
class NoAdProvider implements AdProvider {
  const NoAdProvider();

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
  Future<bool> show(BuildContext context, AdPlacement placement) async => false;
}
