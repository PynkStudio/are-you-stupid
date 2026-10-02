/// The multiplayer AI Director's runtime (Phase 8 —
/// [[Multiplayer AI Director]]). Lives on whichever phone the host elects
/// (`AI_DIRECTOR_ASSIGNMENT`), reusing the exact same building blocks as
/// single-player's Phase 5 pre-generation cache —
/// [AppleAIService]/[ChallengeValidator]/`buildFromProposal`'s validated
/// proposal pipeline — but pushes results over the wire
/// ([PartySession.sendAiRoundProposal]/`sendAiCommentaryProposal`) instead
/// of into a local ring: the host's own single-slot `pendingAiProposal` is
/// the cache, so this class only ever keeps one round proposal in flight,
/// mirroring `RoomHost`'s "never wait" contract from the other side.
///
/// Every phone runs one of these (constructed alongside its
/// [PartySession]), not just the elected Director — it's simply inert
/// (announces capabilities, generates nothing) until
/// [PartyDirectorAssignedEvent] names this phone's own `selfClientId`.
///
/// This file is PURE DART: no Flutter imports — it composes `lib/ai/`
/// exactly like `game_screen.dart` does, just over a [PartySession]
/// instead of a [GameEngine].
library;

import 'dart:async';

import '../../ai/apple_ai_service.dart';
import '../../ai/challenge_validator.dart';
import '../../ai/commentary.dart';
import '../../ai/feature_flags.dart';
import '../../ai/generated_challenge.dart';
import '../../i18n/app_locale.dart';
import '../engine/party_session.dart';
import '../engine/party_state.dart';

class PartyAiDirector {
  PartyAiDirector({
    required PartySession session,
    required AppleAIService service,
    required Future<AiFeatureFlags> Function() loadFlags,
    ChallengeValidator validator = const ChallengeValidator(),
  })  : _session = session,
        _service = service,
        _validator = validator,
        _flagsFuture = loadFlags() {
    _eventsSub = session.events.listen(_onEvent);
    unawaited(_initFlags());
  }

  final PartySession _session;
  final AppleAIService _service;
  final ChallengeValidator _validator;
  late final StreamSubscription<PartyEvent> _eventsSub;

  /// Stored (not just the resolved value) so any caller — in particular
  /// [_announceCapabilities], which fires once on [PartyJoinedEvent] and
  /// can't afford to silently no-op if that happens to race ahead of
  /// [_flags] resolving — can `await` it directly instead of racing a
  /// nullable field. Awaiting an already-completed `Future` is safe and
  /// synchronous-fast, so this costs nothing once flags have loaded.
  final Future<AiFeatureFlags> _flagsFuture;

  /// Built once real flags resolve (see [_initFlags]) — `null` until then,
  /// same cold-start-is-a-no-op contract every other async-flag-gated
  /// class in `lib/ai/` already has ([AIChallengeProvider]).
  CommentaryProvider? _commentary;

  AiFeatureFlags? _flags;
  bool _isDirector = false;
  bool _generatingRound = false;
  int _level = 5; // matches the host's own fixed multiplayer level today.

  static const _recentCap = 4;
  final List<ServedChallengeStamp> _recentServed = [];

  Future<void> _initFlags() async {
    final flags = await _flagsFuture;
    _flags = flags;
    _commentary = CommentaryProvider(service: _service, flags: flags);
  }

  void dispose() {
    _eventsSub.cancel();
  }

  void _onEvent(PartyEvent event) {
    switch (event) {
      case PartyJoinedEvent():
        unawaited(_announceCapabilities());
      case PartyDirectorAssignedEvent(:final assignment):
        _isDirector = assignment.directorPeerId == _session.state.selfClientId;
        if (_isDirector) unawaited(_maybeGenerateRound());
      case PartyRoundStartedEvent(:final roundStart):
        _level = (roundStart.config['level'] as int?) ?? _level;
        unawaited(_maybeGenerateRound());
      case PartyAiChallengeRoundEvent(:final round):
        _level = (round.proposal['difficulty'] as Map?)?['level'] as int? ?? _level;
        unawaited(_maybeGenerateRound());
      case PartyEliminatedEvent(:final eliminated):
        unawaited(_maybeSendCommentary(kind: CommentaryKind.elimination, roundId: eliminated.roundId));
      case PartyGameEndEvent(:final end):
        final wonIt = end.winnerId != null && end.winnerId == _session.state.selfClientId;
        unawaited(_maybeSendCommentary(
          kind: wonIt ? CommentaryKind.winner : CommentaryKind.loser,
          roundId: '',
        ));
      default:
        break;
    }
  }

  /// Announces this phone's on-device model availability once, right after
  /// joining — the host's election ([[Multiplayer AI Director]]) reads
  /// whatever arrived by the time it calls `startGame()`. Awaits
  /// [_flagsFuture] directly (not the nullable [_flags] field) so this
  /// can't lose the race against flags still loading — `PartyJoinedEvent`
  /// fires early in the connection lifecycle and must not silently skip
  /// announcing just because flags hadn't resolved yet at that exact
  /// moment.
  Future<void> _announceCapabilities() async {
    final flags = await _flagsFuture;
    if (!flags.aiMultiplayerDirectorEnabled) {
      _session.sendAiCapabilities(aiAvailable: false);
      return;
    }
    final availability = await _service.available();
    // v1 keeps computeRank a single tier — see the Decision Log on why a
    // finer SoC-based rank isn't worth a new battery/device-info dependency.
    _session.sendAiCapabilities(
      aiAvailable: availability.isAvailable,
      computeRank: availability.isAvailable ? 1 : 0,
    );
  }

  /// Generates one validated round proposal and sends it ahead of need —
  /// called whenever a round opens (scripted or AI), so there's time for
  /// generation to land before the *next* one starts. A no-op unless this
  /// phone is the elected Director, the flag is on, and nothing is already
  /// in flight (the same single-in-flight discipline
  /// [PrefetchLoop][../../ai/prefetch_loop.dart] enforces for single-player).
  Future<void> _maybeGenerateRound() async {
    if (!_isDirector || _generatingRound) return;
    final flags = _flags;
    if (flags == null ||
        !flags.aiMultiplayerDirectorEnabled ||
        !flags.aiChallengeGenerationEnabled) {
      return;
    }

    _generatingRound = true;
    try {
      final availability = await _service.available();
      if (!availability.isAvailable) return;

      final result = await _service.requestChallenge(
        unitId: 'director-${DateTime.now().microsecondsSinceEpoch}',
        locale: AppLocale.en,
        profile: {'level': _level, 'allowTricks': _level >= 6},
      );
      if (!result.ok || result.proposal == null) return;

      final ChallengeProposal proposal;
      try {
        proposal = ChallengeProposal.fromJson(result.proposal!);
      } catch (_) {
        return;
      }

      final verdict = _validator.validate(
        proposal,
        ValidationContext(
          level: _level,
          locale: AppLocale.en,
          allowTricks: _level >= 6,
          recentServed: List.of(_recentServed),
        ),
      );
      if (verdict is! VerdictValid) return;

      _recentServed.add(ServedChallengeStamp.ofProposal(proposal));
      if (_recentServed.length > _recentCap) {
        _recentServed.removeAt(0);
      }
      // The host mints the real roundId when it actually opens this round
      // (RoomHost.startAiRound) — this one is only for the Director's own
      // bookkeeping, never read back by the host.
      _session.sendAiRoundProposal(
        roundId: 'director-${DateTime.now().microsecondsSinceEpoch}',
        proposal: proposal.toJson(),
      );
    } finally {
      _generatingRound = false;
    }
  }

  Future<void> _maybeSendCommentary({required CommentaryKind kind, required String roundId}) async {
    if (!_isDirector) return;
    final flags = _flags;
    final commentary = _commentary;
    if (flags == null || commentary == null) return; // flags not resolved yet — cold start.
    if (!flags.aiMultiplayerDirectorEnabled) return;
    final availability = await _service.available();
    if (!availability.isAvailable) return;

    final text = await commentary.line(kind: kind, locale: AppLocale.en);
    // `CommentaryProvider.line` always returns *something* (static-bank
    // fallback included, [[AI Commentary]]) — only send when the model
    // actually produced this line, never the static fallback: every phone
    // already has the same static pools locally and doesn't need the
    // Director to relay one.
    if (!isCommentaryLineValid(text, kind)) return;
    _session.sendAiCommentaryProposal(kind: kind.wire, roundId: roundId, text: text);
  }
}
