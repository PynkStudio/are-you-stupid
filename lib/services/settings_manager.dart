import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sound + haptics toggles. Persisted locally, no account, no network.
class SettingsManager extends ChangeNotifier {
  SettingsManager(this._prefs);

  static const _kSound = 'ays.sound';
  static const _kHaptics = 'ays.haptics';
  static const _kRoasts = 'ays.roasts';

  final SharedPreferences _prefs;

  static Future<SettingsManager> load() async =>
      SettingsManager(await SharedPreferences.getInstance());

  bool get soundEnabled => _prefs.getBool(_kSound) ?? true;
  bool get hapticsEnabled => _prefs.getBool(_kHaptics) ?? true;

  /// When off, the game only uses the neutral feedback lines.
  bool get roastsEnabled => _prefs.getBool(_kRoasts) ?? true;

  Future<void> setSound(bool value) async {
    await _prefs.setBool(_kSound, value);
    notifyListeners();
  }

  Future<void> setHaptics(bool value) async {
    await _prefs.setBool(_kHaptics, value);
    notifyListeners();
  }

  Future<void> setRoasts(bool value) async {
    await _prefs.setBool(_kRoasts, value);
    notifyListeners();
  }
}
