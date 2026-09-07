/// ChallengeProvider seam. The engine talks to this, never to a concrete
/// source: scripted today, AI behind a pre-generation cache later
/// ([[AI Challenge Generation]], [[Dynamic AI Director]]).
library;

import '../core/challenge_generator.dart';
import '../core/difficulty.dart';
import '../i18n/app_locale.dart';
import 'generated_challenge.dart';

/// Everything a provider needs to pick the next challenge.
class ChallengeContext {
  const ChallengeContext({
    required this.level,
    required this.locale,
    this.seed = 0,
    this.allowTricks = false,
  });

  /// The round number; gating follows [Difficulty.isStarter],
  /// [Difficulty.speedForLevel] and [Difficulty.allowsTricks] exactly like
  /// the scripted registry ([Difficulty Curve]).
  final int level;

  /// The player's current language.
  final AppLocale locale;

  /// Determinism seed for multiplayer rounds; 0 = provider decides (solo).
  final int seed;

  /// Mirror of [Difficulty.allowsTricks] at [level]. Real AI providers join
  /// with Phase 2; today only the scripted floor consumes this.
  final bool allowTricks;
}

/// Gives the engine a challenge for this context.
///
/// Providers never throw and never block. `null` means "nothing to offer
/// right now" (the AI prefetch provider uses it); a composed front-to-back
/// pipeline ([[AI Challenge Generation]] → `FallbackChallengeProvider`)
/// swallows the nulls and always lands on the scripted floor, so the top of
/// the pipeline never returns null in a healthy composition.
abstract class ChallengeProvider {
  GeneratedChallenge? next(ChallengeContext context);

  /// Forget short-term memory (recent-template dedupe) at the start of a run.
  void reset();
}

/// The existing weighted-selection logic, unchanged. Always present: the
/// floor every composed pipeline ends on.
///
/// Returns a `scripted`-sourced [GeneratedChallenge]. The `seed` in the
/// [ChallengeContext] is ignored — solo play keeps the generator's own rng,
/// exactly as before; deterministic seeded rebuilds stay on
/// `lib/challenges/registry.dart` → `buildFromSeed` (multiplayer).
class ScriptedChallengeProvider implements ChallengeProvider {
  ScriptedChallengeProvider({required ChallengeGenerator generator})
      : _generator = generator;

  final ChallengeGenerator _generator;

  @override
  GeneratedChallenge? next(ChallengeContext context) {
    _generator.locale = context.locale;
    final challenge = _generator.next(context.level);
    return GeneratedChallenge(challenge: challenge, source: 'scripted');
  }

  @override
  void reset() => _generator.reset();
}

/// Shell for the telemetry-driven bias ([[Player Telemetry and Adaptive
/// Difficulty]], Phase 3). Today it passes straight through: with no profile
/// a cold start behaves exactly like the scripted path.
class AdaptiveChallengeProvider implements ChallengeProvider {
  AdaptiveChallengeProvider({required ChallengeProvider inner})
      : _inner = inner;

  final ChallengeProvider _inner;

  @override
  GeneratedChallenge? next(ChallengeContext context) => _inner.next(context);

  @override
  void reset() => _inner.reset();
}

/// Composition front-to-back: tries the AI-facing provider first (null until
/// Phases 2/5), then always lands on the scripted floor. The engine's default
/// provider and the one the run can rely on to never return null
/// ([[Pre-generation Cache]]).
class FallbackChallengeProvider implements ChallengeProvider {
  FallbackChallengeProvider({
    required ChallengeProvider scripted,
    ChallengeProvider? ai,
  })  : _scripted = scripted,
        _ai = ai;

  final ChallengeProvider _scripted;
  final ChallengeProvider? _ai;

  @override
  GeneratedChallenge? next(ChallengeContext context) =>
      _ai?.next(context) ?? _scripted.next(context);

  @override
  void reset() {
    _ai?.reset();
    _scripted.reset();
  }
}