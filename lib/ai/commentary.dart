/// AI Commentary (Phase 4 of the AI Director plan, `docs/AI/AI
/// Commentary.md`): the static-bank-first ladder that picks a one-line
/// flavor line for a moment in the game, preferring a fresh AI line when the
/// flag is on and the model is available, and always falling back to the
/// game's existing static pools ([[Privacy and Offline]] → nothing ever
/// blocks, [[Quality Neutrality and Guardrails]] → every category has a
/// scripted fallback).
///
/// [CommentaryProvider.line] is `async` on purpose — it awaits the model —
/// so `GameEngine.fail()`/`.pass()` never call it (the game loop never
/// awaits a model, [[Performance and Resource Budgets]]). Single-player
/// reaches the player through `solo_commentary.dart`'s prefetched ring;
/// multiplayer through `PartyAiDirector`.
///
/// This file is PURE DART except for the same `AppleAIService` bridge every
/// other `lib/ai/` file already depends on.
library;

import 'dart:math';

import '../data/roasts.dart';
import '../i18n/app_locale.dart';
import 'apple_ai_service.dart';
import 'challenge_validator.dart'
    show
        kForbiddenTokens,
        kForbiddenTokensLocalized,
        kMetaAiTokens,
        kMetaAiTokensLocalized,
        textAllowlistFor;
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
  instantFailure,

  /// Single-player run end: the verdict headline on the Game Over card,
  /// written from the run's own facts (level, best, what killed it).
  gameOver;

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

/// Strips what models habitually wrap a line in (quotes, guillemets,
/// surrounding whitespace) before validation, so a good line isn't rejected
/// for its packaging.
String normalizeCommentaryLine(String text) {
  var s = text.trim();
  const wrappers = '"“”«»„';
  while (s.isNotEmpty && wrappers.contains(s[0])) {
    s = s.substring(1).trimLeft();
  }
  while (s.isNotEmpty && wrappers.contains(s[s.length - 1])) {
    s = s.substring(0, s.length - 1).trimRight();
  }
  return s;
}

/// Runs the same neutrality/tone checks
/// [ChallengeValidator][../ai/challenge_validator.dart] applies to a full
/// proposal, narrowed to a single line of text: character allowlist (strict
/// ASCII for English, Latin script for the other locales), forbidden tokens,
/// no meta-AI references, under the kind's word cap, and at most one
/// sentence terminator (`.`/`!`/`?`) — [[AI Commentary]]'s "always one
/// sentence" rule.
bool isCommentaryLineValid(
  String text,
  CommentaryKind kind, {
  AppLocale locale = AppLocale.en,
}) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return false;
  if (!textAllowlistFor(locale).hasMatch(trimmed)) return false;

  final words = trimmed.split(RegExp(r'\s+'));
  if (words.length > kind.maxWords) return false;

  final lower = trimmed.toLowerCase();
  for (final forbidden in {...kForbiddenTokens, ...kForbiddenTokensLocalized}) {
    if (lower.contains(forbidden)) return false;
  }
  final tokens = lower.split(RegExp(r"[^\p{L}']+", unicode: true));
  for (final meta in {...kMetaAiTokens, ...kMetaAiTokensLocalized}) {
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
    return await aiLine(
          kind: kind,
          locale: locale,
          context: context,
          allowSpicy: allowSpicy,
        ) ??
        fallback();
  }

  /// The AI rung alone: a validated, not-recently-used model line, or
  /// `null` for every failure mode (flag off, model unavailable, refused,
  /// invalid, duplicate). For call sites that show *nothing extra* rather
  /// than a static line when the model has nothing — the single-player
  /// wrong-flash aside ([[AI Commentary]] → Where the lines land).
  Future<String?> aiLine({
    required CommentaryKind kind,
    required AppLocale locale,
    Map<String, Object?> context = const {},
    bool allowSpicy = true,
  }) async {
    if (!_flags.aiCommentaryEnabled) return null;

    final availability = await _service.available();
    if (!availability.isAvailable) return null;

    final result = await _service.requestCommentary(
      unitId: 'commentary-${DateTime.now().microsecondsSinceEpoch}',
      locale: locale,
      kind: kind.wire,
      context: {
        ...context,
        'spicy': allowSpicy,
        'recentLines': List<String>.from(_recentLines),
      },
    );
    if (!result.ok || result.text == null) return null;

    final text = normalizeCommentaryLine(result.text!);
    if (!isCommentaryLineValid(text, kind, locale: locale)) return null;
    if (_recentLines.contains(text)) return null;

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
    case CommentaryKind.gameOver:
      return Roasts.gameOver(rng: rng, allowSpicy: allowSpicy, locale: locale);
  }
}
