import 'package:flutter/services.dart';

import 'settings_manager.dart';

/// Vibration feedback. Every call is a no-op when the player turned it off.
class HapticManager {
  HapticManager(this._settings);

  final SettingsManager _settings;

  bool get _on => _settings.hapticsEnabled;

  void tap() {
    if (_on) HapticFeedback.selectionClick();
  }

  void correct() {
    if (_on) HapticFeedback.lightImpact();
  }

  void wrong() {
    if (_on) HapticFeedback.heavyImpact();
  }

  Future<void> record() async {
    if (!_on) return;
    await HapticFeedback.mediumImpact();
    await Future<void>.delayed(const Duration(milliseconds: 90));
    await HapticFeedback.mediumImpact();
  }
}
