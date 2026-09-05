import 'package:flutter/services.dart';

import 'settings_manager.dart';

/// Audio without a single asset file: platform system sounds only.
///
/// Swapping in real sfx later = implementing [SoundBackend] and passing it in.
abstract class SoundBackend {
  Future<void> click();
  Future<void> alert();
}

class SystemSoundBackend implements SoundBackend {
  const SystemSoundBackend();

  @override
  Future<void> click() => SystemSound.play(SystemSoundType.click);

  @override
  Future<void> alert() => SystemSound.play(SystemSoundType.alert);
}

class SoundManager {
  SoundManager(this._settings, {SoundBackend backend = const SystemSoundBackend()})
      : _backend = backend;

  final SettingsManager _settings;
  final SoundBackend _backend;

  bool get _on => _settings.soundEnabled;

  Future<void> button() async {
    if (_on) await _backend.click();
  }

  Future<void> correct() async {
    if (_on) await _backend.click();
  }

  Future<void> wrong() async {
    if (_on) await _backend.alert();
  }

  Future<void> levelUp() async {
    if (_on) await _backend.click();
  }

  Future<void> record() async {
    if (!_on) return;
    await _backend.click();
    await Future<void>.delayed(const Duration(milliseconds: 110));
    await _backend.click();
  }
}
