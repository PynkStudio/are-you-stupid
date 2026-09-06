import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../i18n/app_locale.dart';

/// Sound + haptics + language. Persisted locally, no account, no network.
class SettingsManager extends ChangeNotifier {
  SettingsManager(this._prefs);

  static const _kSound = 'ays.sound';
  static const _kHaptics = 'ays.haptics';
  static const _kRoasts = 'ays.roasts';
  static const _kLocale = 'ays.locale';
  static const _kNoAdsPurchased = 'ays.noAdsPurchased';

  final SharedPreferences _prefs;

  static Future<SettingsManager> load() async =>
      SettingsManager(await SharedPreferences.getInstance());

  bool get soundEnabled => _prefs.getBool(_kSound) ?? true;
  bool get hapticsEnabled => _prefs.getBool(_kHaptics) ?? true;

  /// When off, the game only uses the neutral feedback lines.
  bool get roastsEnabled => _prefs.getBool(_kRoasts) ?? true;

  /// The chosen language, or the device language when nothing was chosen —
  /// see [localeIsSystemDefault].
  AppLocale get locale {
    final saved = _prefs.getString(_kLocale);
    if (saved != null) return AppLocale.fromCode(saved);
    return AppLocale.fromCode(PlatformDispatcher.instance.locale.languageCode);
  }

  /// True while no language has been explicitly chosen (following the
  /// device's language instead).
  bool get localeIsSystemDefault => _prefs.getString(_kLocale) == null;

  /// True once the "remove ads" IAP has been bought or restored. Set only by
  /// `PurchaseManager` after the store confirms it — never by UI code
  /// directly — see docs/Product/Monetization and Ads.md.
  bool get noAdsPurchased => _prefs.getBool(_kNoAdsPurchased) ?? false;

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

  /// Pass `null` to follow the device language again.
  Future<void> setLocale(AppLocale? value) async {
    if (value == null) {
      await _prefs.remove(_kLocale);
    } else {
      await _prefs.setString(_kLocale, value.code);
    }
    notifyListeners();
  }

  Future<void> setNoAdsPurchased(bool value) async {
    await _prefs.setBool(_kNoAdsPurchased, value);
    notifyListeners();
  }
}
