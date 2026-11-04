import 'dart:math';

import '../i18n/app_locale.dart';
import 'challenge.dart';
import 'difficulty.dart';
import 'foldable.dart';

/// Picks the next challenge. Weighted-random, level gated, no immediate repeats.
class ChallengeGenerator {
  ChallengeGenerator({
    required List<ChallengeTemplate> templates,
    Random? random,
    this.locale = AppLocale.en,
    DeviceCapabilities Function()? capabilities,
    FoldableState Function()? deviceState,
  }) : _templates = templates,
       _rng = random ?? Random(),
       _capabilities = capabilities ?? (() => DeviceCapabilities.none),
       _deviceState = deviceState ?? (() => FoldableState.unknown);

  final List<ChallengeTemplate> _templates;
  final Random _rng;
  final List<String> _recent = [];

  /// Live device facts, read at every pick. Default: a conventional phone,
  /// so hardware templates never appear ([[Foldable Architecture]]).
  final DeviceCapabilities Function() _capabilities;
  final FoldableState Function() _deviceState;

  /// The previous pick needed hardware. Two physical rounds never run back
  /// to back: no rapid repetitive folding ([[Unfold Your Brain]] → Safety).
  bool _lastWasHardware = false;

  /// The player's current language. Mutable so the UI layer can sync it from
  /// settings without recreating the generator.
  AppLocale locale;

  static const _memory = 4;

  List<ChallengeTemplate> get templates => List.unmodifiable(_templates);

  void reset() {
    _recent.clear();
    _lastWasHardware = false;
  }

  Challenge next(int level) {
    final speed = Difficulty.speedForLevel(level);
    final params = ChallengeParams(
      level: level,
      rng: _rng,
      speed: speed,
      locale: locale,
    );
    return _pick(level).build(params);
  }

  ChallengeTemplate _pick(int level) {
    final caps = _capabilities();
    final device = _deviceState();
    final runnable = _templates
        .where(
          (t) =>
              !t.needsHardware ||
              (!_lastWasHardware && t.eligibleOn(caps, device)),
        )
        .toList();
    var pool = runnable.where((t) {
      if (t.minLevel > level) return false;
      if (Difficulty.isStarter(level) && !t.starter) return false;
      return true;
    }).toList();

    if (pool.isEmpty) pool = runnable.where((t) => t.starter).toList();
    if (pool.isEmpty) pool = runnable.where((t) => !t.needsHardware).toList();
    if (pool.isEmpty) pool = [..._templates];

    // Avoid repeating what we just played, unless there is nothing else.
    final fresh = pool.where((t) => !_recent.contains(t.id)).toList();
    if (fresh.isNotEmpty) pool = fresh;

    final total = pool.fold<double>(0, (sum, t) => sum + t.weight);
    var roll = _rng.nextDouble() * total;
    var chosen = pool.last;
    for (final t in pool) {
      roll -= t.weight;
      if (roll <= 0) {
        chosen = t;
        break;
      }
    }

    _lastWasHardware = chosen.needsHardware;
    _recent.add(chosen.id);
    if (_recent.length > _memory) _recent.removeAt(0);
    return chosen;
  }
}
