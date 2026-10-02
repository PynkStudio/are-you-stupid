// MultiplayerProfileManager is the mobile side's only persisted multiplayer
// state — name/emoji for "join relaxation" and lifetime stats. See
// [[Multiplayer Client (Mobile)]].
import 'package:are_you_stupid/services/multiplayer_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MultiplayerProfileManager', () {
    test('defaults to empty profile and zeroed stats', () async {
      SharedPreferences.setMockInitialValues({});
      final profile = await MultiplayerProfileManager.load();

      expect(profile.playerName, '');
      expect(profile.emoji, '');
      expect(profile.matchesPlayed, 0);
      expect(profile.wins, 0);
      expect(profile.bestStanding, isNull);
    });

    test('setProfile persists name and emoji, trimmed', () async {
      SharedPreferences.setMockInitialValues({});
      final profile = await MultiplayerProfileManager.load();

      await profile.setProfile(playerName: '  Massimo  ', emoji: '🔥');

      expect(profile.playerName, 'Massimo');
      expect(profile.emoji, '🔥');
    });

    test('setProfile survives across a fresh load (persisted)', () async {
      SharedPreferences.setMockInitialValues({});
      final first = await MultiplayerProfileManager.load();
      await first.setProfile(playerName: 'Sami', emoji: '');

      final reloaded = await MultiplayerProfileManager.load();
      expect(reloaded.playerName, 'Sami');
    });

    test('recordMatch increments matchesPlayed and wins only on a win', () async {
      SharedPreferences.setMockInitialValues({});
      final profile = await MultiplayerProfileManager.load();

      await profile.recordMatch(standing: 2, won: false);
      expect(profile.matchesPlayed, 1);
      expect(profile.wins, 0);

      await profile.recordMatch(standing: 1, won: true);
      expect(profile.matchesPlayed, 2);
      expect(profile.wins, 1);
    });

    test('bestStanding only ever improves (lower is better)', () async {
      SharedPreferences.setMockInitialValues({});
      final profile = await MultiplayerProfileManager.load();

      await profile.recordMatch(standing: 3, won: false);
      expect(profile.bestStanding, 3);

      await profile.recordMatch(standing: 5, won: false);
      expect(profile.bestStanding, 3, reason: 'a worse finish must not overwrite the best');

      await profile.recordMatch(standing: 1, won: true);
      expect(profile.bestStanding, 1);
    });

    test('notifies listeners on every write', () async {
      SharedPreferences.setMockInitialValues({});
      final profile = await MultiplayerProfileManager.load();
      var notifications = 0;
      profile.addListener(() => notifications++);

      await profile.setProfile(playerName: 'X', emoji: '');
      await profile.recordMatch(standing: 1, won: true);

      expect(notifications, 2);
    });
  });
}
