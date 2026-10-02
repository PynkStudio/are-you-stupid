/// AI Commentary (Phase 4 of the AI Director plan, `docs/AI/AI
/// Commentary.md`): the static-bank-first ladder that picks a one-line
/// flavor line for a moment in the game, preferring a fresh AI line when the
/// flag is on and the model is available, and always falling back to the
/// game's existing static pools ([[Privacy and Offline]] → nothing ever
/// blocks, [[Quality Neutrality and Guardrails]] → every category has a
/// scripted fallback).
///
/// **Scope note (Phase 4 vs Phase 5):** [CommentaryProvider.line] is
/// `async` on purpose — it awaits the model — so nothing here is wired into
/// `GameEngine.fail()`/`.pass()` yet: those must stay synchronous (the game
/// loop never awaits a model, [[Performance and Resource Budgets]]). Real
/// wiring into the live flash slots is [[Development Plan]] Phase 5's job,
/// once a pre-generation cache exists to serve an already-fetched line
/// synchronously. This file is the ladder logic + the real bridge call;
/// Phase 5 makes it actually reach the player without ever waiting on it.
///
/// This file is PURE DART except for the same `AppleAIService` bridge every
/// other `lib/ai/` file already depends on.
library;

import 'dart:math';

import '../data/roasts.dart';
import '../i18n/app_locale.dart';
import 'apple_ai_service.dart';
import 'challenge_validator.dart' show kAsciiAllowlist, kForbiddenTokens, kMetaAiTokens;
import 'feature_flags.dart';

/// The closed vocabulary of commentary moments ([[AI Commentary]] →
/// Kinds). One call, one kind, one line.
enum CommentaryKind {
  correct,
  wrong,
  streak,
  comeback,
  elimination,
  finalRound,
  winner,
  loser,
  closeMatch,
  instantFailure;

  /// Wire name sent to `requestCommentary`'s `kind` argument.
  String get wire => name;

  /// Hard word cap, enforced before any line reaches the player
  /// ([[AI Commentary]] → length caps): 6 for the upbeat/short kinds, 12 for
  /// the roasted ones.
  int get maxWords => switch (this) {
        CommentaryKind.correct ||
        CommentaryKind.streak =>
          6,
        _ => 12,
      };
}

/// Runs the same neutrality/tone/ASCII checks
/// [ChallengeValidator][../ai/challenge_validator.dart] applies to a full
/// proposal, narrowed to a single line of text: ASCII allowlist, forbidden
/// tokens, no meta-AI references, under the kind's word cap, and at most one
/// sentence terminator (`.`/`!`/`?`) — [[AI Commentary]]'s "always one
/// sentence" rule.
bool isCommentaryLineValid(String text, CommentaryKind kind) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return false;
  if (!kAsciiAllowlist.hasMatch(trimmed)) return false;

  final words = trimmed.split(RegExp(r'\s+'));
  if (words.length > kind.maxWords) return false;

  final lower = trimmed.toLowerCase();
  for (final forbidden in kForbiddenTokens) {
    if (lower.contains(forbidden)) return false;
  }
  final tokens = lower.split(RegExp(r"[^a-z']+"));
  for (final meta in kMetaAiTokens) {
    if (tokens.contains(meta)) return false;
  }

  final terminators = RegExp(r'[.!?]').allMatches(trimmed).length;
  if (terminators > 1) return false;

  return true;
}

/// Composes the bridge + static fallback + a small recent-lines dedupe into
/// one call sites can await. Never throws — every failure mode (flag off,
/// model unavailable, refused, invalid, duplicate) lands on the static bank.
class CommentaryProvider {
  CommentaryProvider({
    required AppleAIService service,
    required AiFeatureFlags flags,
    Random? rng,
  })  : _service = service,
        _flags = flags,
        _rng = rng ?? Random();

  final AppleAIService _service;
  final AiFeatureFlags _flags;
  final Random _rng;

  /// Bounded so this never grows unboundedly across a long session — old
  /// enough lines are fair to repeat again.
  static const _recentCap = 12;
  final List<String> _recentLines = [];

  /// Picks a line for [kind]. [staticFallback], when given, overrides the
  /// default static-pool mapping (mainly for tests and for a caller with
  /// more specific static copy than the shared pools).
  Future<String> line({
    required CommentaryKind kind,
    required AppLocale locale,
    Map<String, Object?> context = const {},
    bool allowSpicy = true,
    String Function()? staticFallback,
  }) async {
    final fallback = staticFallback ??
        () => _defaultStaticFallback(kind, rng: _rng, allowSpicy: allowSpicy, locale: locale);

    if (!_flags.aiCommentaryEnabled) return fallback();

    final availability = await _service.available();
    if (!availability.isAvailable) return fallback();

    final result = await _service.requestCommentary(
      unitId: 'commentary-${DateTime.now().microsecondsSinceEpoch}',
      locale: locale,
      kind: kind.wire,
      context: {...context, 'recentLines': List<String>.from(_recentLines)},
    );
    if (!result.ok || result.text == null) return fallback();

    final text = result.text!;
    if (!isCommentaryLineValid(text, kind)) return fallback();
    if (_recentLines.contains(text)) return fallback();

    _remember(text);
    return text;
  }

  void _remember(String text) {
    _recentLines.add(text);
    if (_recentLines.length > _recentCap) {
      _recentLines.removeAt(0);
    }
  }
}

/// The static-bank-first default: reuses the existing single-player
/// `Roasts` pools ([[AI Commentary]]) — a few multiplayer-only kinds
/// (`elimination`, `finalRound`, `winner`, `closeMatch`) have no dedicated
/// static pool of their own yet (that would mean authoring new `roast.*`
/// copy across all six locales), so they map onto the tonally-closest
/// existing pool rather than blocking this phase on new content.
String _defaultStaticFallback(
  CommentaryKind kind, {
  required Random rng,
  required bool allowSpicy,
  required AppLocale locale,
}) {
  switch (kind) {
    case CommentaryKind.correct:
    case CommentaryKind.streak:
    case CommentaryKind.comeback:
    case CommentaryKind.winner:
    case CommentaryKind.closeMatch:
    case CommentaryKind.finalRound:
      return Roasts.pick(Roasts.praise(locale), rng);
    case CommentaryKind.wrong:
    case CommentaryKind.instantFailure:
    case CommentaryKind.elimination:
    case CommentaryKind.loser:
      return Roasts.forMistake(rng: rng, allowSpicy: allowSpicy, locale: locale);
  }
}
