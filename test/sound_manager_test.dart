import 'package:are_you_stupid/services/settings_manager.dart';
import 'package:are_you_stupid/services/sound_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RecordingSoundBackend implements SoundBackend {
  final cues = <SoundCue>[];

  @override
  Future<void> play(SoundCue cue) async => cues.add(cue);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every semantic event selects its own generated asset', () async {
    SharedPreferences.setMockInitialValues({});
    final backend = _RecordingSoundBackend();
    final sounds = SoundManager(await SettingsManager.load(), backend: backend);

    await sounds.button();
    await sounds.correct();
    await sounds.wrong();
    await sounds.levelUp();
    await sounds.record();

    expect(backend.cues, SoundCue.values);
    expect(AssetSoundBackend.volume, 0.32);
  });

  test('the sound setting gates every generated asset', () async {
    SharedPreferences.setMockInitialValues({'ays.sound': false});
    final backend = _RecordingSoundBackend();
    final sounds = SoundManager(await SettingsManager.load(), backend: backend);

    await sounds.button();
    await sounds.correct();
    await sounds.wrong();
    await sounds.levelUp();
    await sounds.record();

    expect(backend.cues, isEmpty);
  });
}
