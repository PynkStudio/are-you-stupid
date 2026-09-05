import 'dart:math';

import 'challenge.dart';
import 'difficulty.dart';

/// Picks the next challenge. Weighted-random, level gated, no immediate repeats.
class ChallengeGenerator {
  ChallengeGenerator({
    required List<ChallengeTemplate> templates,
    Random? random,
  })  : _templates = templates,
        _rng = random ?? Random();


  final List<ChallengeTemplate> _templates;
  final Random _rng;
  final List<String> _recent = [];

  static const _memory = 4;

  List<ChallengeTemplate> get templates => List.unmodifiable(_templates);

  void reset() => _recent.clear();

  Challenge next(int level) {
    final speed = Difficulty.speedForLevel(level);
    final params = ChallengeParams(level: level, rng: _rng, speed: speed);
    return _pick(level).build(params);
  }

  ChallengeTemplate _pick(int level) {
    var pool = _templates.where((t) {
      if (t.minLevel > level) return false;
      if (Difficulty.isStarter(level) && !t.starter) return false;
      return true;
    }).toList();

    if (pool.isEmpty) pool = _templates.where((t) => t.starter).toList();
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

    _recent.add(chosen.id);
    if (_recent.length > _memory) _recent.removeAt(0);
    return chosen;
  }
}
