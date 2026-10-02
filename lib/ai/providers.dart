/// ChallengeProvider seam. The engine talks to this, never to a concrete
/// source: scripted today, AI behind a pre-generation cache later
/// ([[AI Challenge Generation]], [[Dynamic AI Director]]).
library;

import 'dart:async' show unawaited;

import '../core/challenge_generator.dart';
import '../core/difficulty.dart';
import '../i18n/app_locale.dart';
import 'apple_ai_service.dart';
import 'challenge_validator.dart';
import 'challenge_vocabulary.dart';
import 'feature_flags.dart';
import 'generated_challenge.dart';
import 'generated_challenge_runtime.dart';
import 'prefetch_loop.dart';
import 'profile_for_prompts.dart';
import 'telemetry.dart';

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

/// Telemetry-driven bias ([[Player Telemetry and Adaptive Difficulty]],
/// Phase 3).
///
/// With no profile (cold start) it passes straight through, behaving exactly
/// like the inner provider. With a profile it applies two, and only two,
/// knobs to the *candidate* the inner provider already offered:
///
/// - **Territory** — a preference for the allowed mechanic the player is
///   weakest at (lowest windowed success rate), surfaced by bounded re-rolls
///   of the inner provider.
/// - **Variety guard** — never serve a candidate whose mechanic is already at
///   [varietyCap] occurrences in the last [varietyWindow] serves, and no
///   adapt-fast loops on a single loss streak.
///
/// Adaptation **never changes the rules** and **never widens what validation
/// allows** — it only re-weights which candidate gets served. The inner
/// provider and `lib/core/` are untouched ([[AI as Playing Style]]).
class AdaptiveChallengeProvider implements ChallengeProvider {
  AdaptiveChallengeProvider({
    required ChallengeProvider inner,
    PlayerGameplayProfile? profile,
    int varietyWindow = 8,
    int varietyCap = 3,
    int maxRerolls = 4,
  })  : _inner = inner,
        _profile = profile,
        _varietyWindow = varietyWindow,
        _varietyCap = varietyCap,
        _maxRerolls = maxRerolls;

  final ChallengeProvider _inner;

  /// Latest observed profile; null = cold start (neutral pass-through).
  PlayerGameplayProfile? _profile;
  void setProfile(PlayerGameplayProfile? profile) => _profile = profile;

  final int _varietyWindow;
  final int _varietyCap;
  final int _maxRerolls;

  final List<String> _recentMechanics = [];

  /// The mechanics the player actually struggles at — below their own
  /// average success rate — weakest first, ignoring ones already at the
  /// variety cap ([[AI Challenge Generation]] → knobs).
  ///
  /// Bug fixed here: this used to return *every* mechanic in the profile
  /// (just sorted), not a genuinely "struggling" subset — so `next()`'s
  /// `targets.contains(mechanic)` check matched almost anything the inner
  /// provider offered, defeating the "prefer the weakest" intent entirely
  /// (caught by `test/ai/telemetry_test.dart`'s "territory prefers the
  /// mechanic the player is weakest at", pre-existing and unrelated to any
  /// multiplayer work — see docs/Meta/Decision Log.md). Below-average is a
  /// simple, self-relative threshold: it needs no tuned constant and always
  /// identifies *some* mechanics as fine even for a struggling player,
  /// unlike a fixed cutoff.
  List<String> _targetMechanics() {
    final profile = _profile;
    if (profile == null) return const [];
    final rates = profile.successRateByMechanic;
    if (rates.isEmpty) return const [];
    final average = rates.values.reduce((a, b) => a + b) / rates.length;
    final entries = rates.entries
        .where((e) => e.value < average)
        .where((e) => _count(_recentMechanics, e.key) < _varietyCap)
        .toList()
      ..sort((a, b) => a.value.compareTo(b.value)); // weakest first
    return [for (final e in entries) e.key];
  }

  static int _count(List<String> list, String id) =>
      list.where((e) => e == id).length;

  @override
  GeneratedChallenge? next(ChallengeContext context) {
    final targets = _targetMechanics();
    GeneratedChallenge? fallback;
    for (var i = 0; i <= _maxRerolls; i++) {
      final candidate = _inner.next(context);
      if (candidate == null) return null;
      final mechanic = candidate.challenge.id;
      fallback = candidate;
      final overCap = _count(_recentMechanics, mechanic) >= _varietyCap;
      // Offer = not over the variety cap AND (neutral when cold, or a
      // mechanic the player struggles at). Anything else gets re-rolled; on
      // exhaustion we serve whatever the inner provider last offered.
      if (!overCap && (_profile == null || targets.contains(mechanic))) {
        return _serve(candidate);
      }
    }
    return _serve(fallback);
  }

  GeneratedChallenge? _serve(GeneratedChallenge? candidate) {
    if (candidate == null) return null;
    _recentMechanics.add(candidate.challenge.id);
    if (_recentMechanics.length > _varietyWindow) {
      _recentMechanics.removeAt(0);
    }
    return candidate;
  }

  @override
  void reset() {
    _recentMechanics.clear();
    _inner.reset();
  }
}

/// The real AI-facing provider (Phase 5): a [PrefetchLoop]-backed cache in
/// front of [AppleAIService.requestChallenge] + [ChallengeValidator] +
/// [buildFromProposal] ([[Pre-generation Cache]]).
///
/// **Self-sustaining prefetch, no engine wiring needed.** [next] is called
/// exactly once per level by [GameEngine][../core/game_engine.dart], right
/// when a level starts — there's no separate "prefetch ahead" event to hook.
/// So every call to [next] does two things: pop whatever the ring already
/// has ready (built from a *previous* call's background fetch), and kick a
/// fresh background fetch keyed by *this* call's context, so it's likely
/// ready by the time the *next* level asks. The one imprecision this trades
/// away: a fetch started at level N targets level N's own context, not
/// N+1's — harmless in practice since the cache key only bands by 10 levels
/// ([_levelBand]), not the exact level.
///
/// **Cold start / not-ready-yet:** [AiFeatureFlags] loads asynchronously
/// (`SharedPreferences`); until that resolves, [next] returns `null` like
/// any other cache miss — [FallbackChallengeProvider] lands on scripted,
/// exactly the same "cold start = neutral" contract
/// [AdaptiveChallengeProvider] already has.
class AIChallengeProvider implements ChallengeProvider {
  AIChallengeProvider({
    required AppleAIService service,
    required Future<AiFeatureFlags> Function() loadFlags,
    ChallengeValidator validator = const ChallengeValidator(),
    PlayerGameplayProfile? Function()? profileSnapshot,
  })  : _service = service,
        _validator = validator,
        _profileSnapshot = profileSnapshot {
    _loop = PrefetchLoop<_CachedChallenge>(fetch: _fetchOne);
    unawaited(_initFlags(loadFlags));
  }

  final AppleAIService _service;
  final ChallengeValidator _validator;
  late final PrefetchLoop<_CachedChallenge> _loop;

  /// Read fresh on every fetch (not captured once) — `game_screen.dart`
  /// constructs this provider before `TelemetryCollector` exists, and the
  /// profile changes round to round anyway. Feeds `requestChallenge`'s
  /// `GetPlayerProfileTool` snapshot ([[Dynamic Profiles and Tool Calling]])
  /// — independent of `aiAdaptiveDifficultyEnabled`, which only gates the
  /// *deterministic* re-weighting `AdaptiveChallengeProvider` does; letting
  /// the model see a truncated profile is already covered by
  /// `aiChallengeGenerationEnabled` alone ([[Privacy and Offline]] — this is
  /// exactly the bounded shape that's allowed into a prompt).
  final PlayerGameplayProfile? Function()? _profileSnapshot;

  AiFeatureFlags? _flags;
  ChallengeContext? _fetchContext;
  String? _cacheKey;

  /// Recent-served dedupe for the validator's freshness check — capped the
  /// same way the design doc's "last 4" dedupe is ([[AI Challenge
  /// Generation]]). Updated only in [next], when a cached item is actually
  /// popped and handed to the engine — **not** inside [_fetchOne] itself,
  /// which would record a mechanic/decoy signature as "served" even for a
  /// background fetch [PrefetchLoop] later discards as stale (a real bug
  /// caught while testing this class: a discarded fetch was still poisoning
  /// the dedupe list, causing the very next legitimate fetch for the same
  /// signature to be rejected as a near-duplicate of something the player
  /// never actually saw).
  static const _recentCap = 4;
  final List<ServedChallengeStamp> _recentServed = [];

  Future<void> _initFlags(Future<AiFeatureFlags> Function() loadFlags) async {
    _flags = await loadFlags();
  }

  @override
  GeneratedChallenge? next(ChallengeContext context) {
    final flags = _flags;
    if (flags == null || !flags.aiChallengeGenerationEnabled) return null;
    if (!aiSupportedLocales(context.locale)) return null;
    // Levels 1-3 stay scripted-only, same as the registry (CLAUDE.md design
    // pillar: "Levels 1-3 stay trivial (starter: true templates only)") —
    // an AI proposal has no `starter` flag to honor that promise by, so it
    // never gets the chance to break it. Found missing while writing the
    // Phase 10 widget test for an AI-served round (see Decision Log).
    if (Difficulty.isStarter(context.level)) return null;

    final key = _keyFor(context);
    if (key != _cacheKey) {
      _cacheKey = key;
      _loop.invalidate();
    }
    _fetchContext = context;

    final popped = _loop.popNext();
    _loop.maybeStart();
    if (popped == null) return null;

    _recentServed.add(popped.stamp);
    if (_recentServed.length > _recentCap) {
      _recentServed.removeAt(0);
    }
    return popped.challenge;
  }

  @override
  void reset() {
    _loop.invalidate();
    _recentServed.clear();
    _cacheKey = null;
  }

  /// Level-banded (not exact) so a level-up mid-band doesn't thrash the
  /// cache key every round; locale/allowTricks changes invalidate exactly.
  String _keyFor(ChallengeContext c) =>
      '${c.locale.code}:${c.level ~/ 10}:${c.allowTricks}';

  Future<_CachedChallenge?> _fetchOne() async {
    final context = _fetchContext;
    final flags = _flags;
    if (context == null || flags == null || !flags.aiChallengeGenerationEnabled) {
      return null;
    }
    final availability = await _service.available();
    if (!availability.isAvailable) return null;

    final result = await _service.requestChallenge(
      unitId: 'challenge-${DateTime.now().microsecondsSinceEpoch}',
      locale: context.locale,
      profile: {
        'level': context.level,
        'allowTricks': context.allowTricks,
        'playerProfile': profileForPrompts(_profileSnapshot?.call()),
        // No stronger id than the mechanic move exists for AI-generated
        // content stamps ([ServedChallengeStamp] only tracks
        // `{mechanic, decoySignature}`) — reused for both fields rather
        // than inventing one, since the tool's real purpose (avoid
        // repeating a mechanic) only needs the mechanic anyway.
        'recentChallenges': [
          for (final stamp in _recentServed)
            {'challengeId': stamp.mechanic, 'mechanic': stamp.mechanic},
        ],
        'availableMechanics': availableMechanicMoves(
          allowTricks: context.allowTricks,
        ),
      },
    );
    if (!result.ok || result.proposal == null) return null;

    final ChallengeProposal proposal;
    try {
      proposal = ChallengeProposal.fromJson(result.proposal!);
    } on FormatException {
      return null;
    }

    // Validated against the recent-served list *as of the moment the fetch
    // started* — deliberately not re-read at the very end, since a fetch
    // that's about to be discarded as stale (see [PrefetchLoop.invalidate])
    // must not have already consumed a "not a near-duplicate" slot that a
    // still-relevant fetch might need.
    final verdict = _validator.validate(
      proposal,
      ValidationContext(
        level: context.level,
        locale: context.locale,
        allowTricks: context.allowTricks,
        recentServed: List.of(_recentServed),
      ),
    );
    if (verdict is! VerdictValid) return null;

    return _CachedChallenge(
      challenge: buildFromProposal(proposal, locale: context.locale),
      stamp: ServedChallengeStamp.ofProposal(proposal),
    );
  }
}

/// A cached-but-not-yet-served item: the stamp travels with the built
/// challenge so [AIChallengeProvider.next] can record it in
/// `_recentServed` only at the moment it's actually popped, not when it's
/// merely generated in the background.
class _CachedChallenge {
  const _CachedChallenge({required this.challenge, required this.stamp});

  final GeneratedChallenge challenge;
  final ServedChallengeStamp stamp;
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