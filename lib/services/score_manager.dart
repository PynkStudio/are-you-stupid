import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local-only score board. Best level is the score; everything else is bragging
/// material for the stats screen.
class ScoreManager extends ChangeNotifier {
  ScoreManager(this._prefs);

  static const _kBest = 'ays.best';
  static const _kAttempts = 'ays.attempts';
  static const _kLevelSum = 'ays.levelSum';
  static const _kStreak = 'ays.streak';
  static const _kRunsSinceAd = 'ays.runsSinceAd';

  final SharedPreferences _prefs;

  static Future<ScoreManager> load() async =>
      ScoreManager(await SharedPreferences.getInstance());

  int get bestLevel => _prefs.getInt(_kBest) ?? 0;
  int get totalAttempts => _prefs.getInt(_kAttempts) ?? 0;
  int get _levelSum => _prefs.getInt(_kLevelSum) ?? 0;
  int get bestStreak => _prefs.getInt(_kStreak) ?? 0;
  int get runsSinceAd => _prefs.getInt(_kRunsSinceAd) ?? 0;

  double get averageLevel =>
      totalAttempts == 0 ? 0 : _levelSum / totalAttempts;

  /// Records a finished run. Returns true when it is a new personal best.
  ///
  /// [countAttempt] is false when the run was extended with a rewarded ad, so
  /// continues do not pollute the attempt count / average.
  Future<bool> recordRun({
    required int level,
    required int fastStreak,
    bool countAttempt = true,
  }) async {
    final isRecord = level > bestLevel;
    if (countAttempt) {
      await _prefs.setInt(_kAttempts, totalAttempts + 1);
      await _prefs.setInt(_kLevelSum, _levelSum + level);
      await _prefs.setInt(_kRunsSinceAd, runsSinceAd + 1);
    }
    if (isRecord) await _prefs.setInt(_kBest, level);
    if (fastStreak > bestStreak) await _prefs.setInt(_kStreak, fastStreak);
    notifyListeners();
    return isRecord;
  }

  Future<void> markInterstitialShown() async {
    await _prefs.setInt(_kRunsSinceAd, 0);
    notifyListeners();
  }

  Future<void> reset() async {
    await _prefs.remove(_kBest);
    await _prefs.remove(_kAttempts);
    await _prefs.remove(_kLevelSum);
    await _prefs.remove(_kStreak);
    await _prefs.remove(_kRunsSinceAd);
    notifyListeners();
  }
}
