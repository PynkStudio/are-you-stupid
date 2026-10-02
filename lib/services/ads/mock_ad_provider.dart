import 'package:flutter/material.dart';

import '../../ui/widgets/mock_ad_overlay.dart';
import 'ad_provider.dart';

/// A fake ad so the whole flow (and its timing) is real without credentials.
class MockAdProvider implements AdProvider {
  @override
  Future<void> initialize() async {}

  @override
  bool get privacyOptionsRequired => false;

  @override
  Future<void> showPrivacyOptions() async {}

  @override
  Future<void> preload(AdPlacement placement) async {}

  @override
  bool isReady(AdPlacement placement) => true;

  @override
  Future<bool> show(BuildContext context, AdPlacement placement) async {
    final rewarded = placement != AdPlacement.interstitial;
    final result = await Navigator.of(context, rootNavigator: true).push<bool>(
      PageRouteBuilder<bool>(
        opaque: true,
        barrierDismissible: false,
        transitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (_, _, _) => MockAdOverlay(
          seconds: rewarded ? 5 : 3,
          rewarded: rewarded,
        ),
      ),
    );
    return result ?? false;
  }
}
