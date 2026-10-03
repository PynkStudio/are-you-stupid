import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../multiplayer/presenter/spoken_identity.dart';

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
  static const _kPersonaId = 'ays.mp.personaId';
  static const _kVerifiedDisplayName = 'ays.mp.verifiedDisplayName';
  static const _kSpokenName = 'ays.mp.spokenName';
  static const _kSpeechPolicy = 'ays.mp.speechPolicy';

  final SharedPreferences _prefs;

  static Future<MultiplayerProfileManager> load() async =>
      MultiplayerProfileManager(await SharedPreferences.getInstance());

  /// Last-used player name, remembered so re-joining is a single tap
  /// ([[Multiplayer Client (Mobile)]] "join relaxation").
  String get playerName => _prefs.getString(_kName) ?? '';

  /// Optional emoji shown beside the name; empty means the auto-generated
  /// colored-circle-and-initial avatar ([[Multiplayer Product]]).
  String get emoji => _prefs.getString(_kEmoji) ?? '';

  String get personaId {
    final existing = _prefs.getString(_kPersonaId);
    if (existing != null && existing.isNotEmpty) return existing;
    final random = Random.secure();
    final id = List.generate(
      4,
      (_) => random.nextInt(0x100000000).toRadixString(16).padLeft(8, '0'),
    ).join();
    _prefs.setString(_kPersonaId, id);
    return id;
  }

  SpokenIdentity spokenIdentityFor(String displayName) {
    final normalized = displayName.trim();
    if (_prefs.getString(_kVerifiedDisplayName) == normalized) {
      final rawPolicy = _prefs.getString(_kSpeechPolicy);
      for (final policy in NameSpeechPolicy.values) {
        if (policy.name == rawPolicy) {
          return SpokenIdentity(
            displayName: normalized,
            spokenName: _prefs.getString(_kSpokenName),
            policy: policy,
          );
        }
      }
    }
    return SpokenIdentity.classify(normalized);
  }

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

  Future<void> setProfile({
    required String playerName,
    required String emoji,
    SpokenIdentity? spokenIdentity,
  }) async {
    await _prefs.setString(_kName, playerName.trim());
    await _prefs.setString(_kEmoji, emoji);
    if (spokenIdentity != null) {
      await _prefs.setString(_kVerifiedDisplayName, spokenIdentity.displayName);
      await _prefs.setString(_kSpeechPolicy, spokenIdentity.policy.name);
      final spokenName = spokenIdentity.spokenName;
      if (spokenName == null) {
        await _prefs.remove(_kSpokenName);
      } else {
        await _prefs.setString(_kSpokenName, spokenName);
      }
    }
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
