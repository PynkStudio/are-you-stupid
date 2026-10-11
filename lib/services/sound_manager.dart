import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

import 'settings_manager.dart';

enum SoundCue { button, correct, wrong, levelUp, record }

abstract class SoundBackend {
  Future<void> play(SoundCue cue);
}

/// Bundled, generated SFX. All files are deliberately mixed at 32% linear
/// amplitude: the raw ElevenLabs masters are much too hot for headphones.
class AssetSoundBackend implements SoundBackend {
  static const volume = 0.32;
  final List<AudioPlayer> _active = [];

  static const _assets = <SoundCue, String>{
    SoundCue.button: 'audio/sfx/button.mp3',
    SoundCue.correct: 'audio/sfx/correct.mp3',
    SoundCue.wrong: 'audio/sfx/wrong.mp3',
    SoundCue.levelUp: 'audio/sfx/level_up.mp3',
    SoundCue.record: 'audio/sfx/record.mp3',
  };

  @override
  Future<void> play(SoundCue cue) async {
    final player = AudioPlayer();
    _active.add(player);
    try {
      await player.play(
        AssetSource(_assets[cue]!),
        volume: volume,
        mode: PlayerMode.lowLatency,
      );
      unawaited(player.onPlayerComplete.first.then((_) => _release(player)));
    } catch (_) {
      await _release(player);
      // Keep a safe audible fallback if a platform cannot decode the asset.
      await SystemSound.play(SystemSoundType.click);
    }
  }

  Future<void> _release(AudioPlayer player) async {
    _active.remove(player);
    await player.dispose();
  }
}

class SoundManager {
  SoundManager(this._settings, {SoundBackend? backend})
    : _backend = backend ?? AssetSoundBackend();

  final SettingsManager _settings;
  final SoundBackend _backend;

  bool get _on => _settings.soundEnabled;

  Future<void> button() async {
    if (_on) await _backend.play(SoundCue.button);
  }

  Future<void> correct() async {
    if (_on) await _backend.play(SoundCue.correct);
  }

  Future<void> wrong() async {
    if (_on) await _backend.play(SoundCue.wrong);
  }

  Future<void> levelUp() async {
    if (_on) await _backend.play(SoundCue.levelUp);
  }

  Future<void> record() async {
    if (_on) await _backend.play(SoundCue.record);
  }
}
