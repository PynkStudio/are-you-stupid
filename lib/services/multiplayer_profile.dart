import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The mobile controller's local multiplayer identity + stats.
///
/// Persisted locally only — no account, no cloud
/// ([[Multiplayer Client (Mobile)]]). Mirrors [SettingsManager]'s shape.
class MultiplayerProfileManager extends ChangeNotifier {
  MultiplayerProfileManager(this._prefs);

  static const _kName = 'ays.mp.playerName';
  static const _kEmoji = 'ays.mp.emoji';
  static const _kMatchesPlayed = 'ays.mp.matchesPlayed';
  static const _kWins = 'ays.mp.wins';
  static const _kBestStanding = 'ays.mp.bestStanding';
  static const _kPrimerSeen = 'ays.mp.permissionsPrimerSeen';

  final SharedPreferences _prefs;

  static Future<MultiplayerProfileManager> load() async =>
      MultiplayerProfileManager(await SharedPreferences.getInstance());

  /// Last-used player name, remembered so re-joining is a single tap
  /// ([[Multiplayer Client (Mobile)]] "join relaxation").
  String get playerName => _prefs.getString(_kName) ?? '';

  /// Optional emoji shown beside the name; empty means the auto-generated
  /// colored-circle-and-initial avatar ([[Multiplayer Product]]).
  String get emoji => _prefs.getString(_kEmoji) ?? '';

  int get matchesPlayed => _prefs.getInt(_kMatchesPlayed) ?? 0;
  int get wins => _prefs.getInt(_kWins) ?? 0;

  /// Best (lowest) final standing across every match played, 1 = winner.
  /// Null until the first match completes.
  int? get bestStanding => _prefs.getInt(_kBestStanding);

  /// True once the player has read the multiplayer permissions primer and
  /// tapped CONTINUE. Until then nothing may touch the local network, so the
  /// iOS Local Network prompt never appears out of context
  /// ([[Multiplayer Client (Mobile)]] "Permissions").
  bool get permissionsPrimerSeen => _prefs.getBool(_kPrimerSeen) ?? false;

  Future<void> markPermissionsPrimerSeen() async {
    await _prefs.setBool(_kPrimerSeen, true);
    notifyListeners();
  }

  Future<void> setProfile({required String playerName, required String emoji}) async {
    await _prefs.setString(_kName, playerName.trim());
    await _prefs.setString(_kEmoji, emoji);
    notifyListeners();
  }

  /// Records one completed match's outcome for this player.
  Future<void> recordMatch({required int standing, required bool won}) async {
    await _prefs.setInt(_kMatchesPlayed, matchesPlayed + 1);
    if (won) await _prefs.setInt(_kWins, wins + 1);
    final best = bestStanding;
    if (best == null || standing < best) {
      await _prefs.setInt(_kBestStanding, standing);
    }
    notifyListeners();
  }
}
