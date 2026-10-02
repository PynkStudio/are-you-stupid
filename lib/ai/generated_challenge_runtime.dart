/// Turns a **validated** [ChallengeProposal] into a real, playable
/// [Challenge] — the piece [[AI Challenge Generation]] and
/// [[AI Challenge Validator]] describe the *shape* of but neither builds.
///
/// [buildFromProposal] is the only entry point; it assumes [ChallengeProposal]
/// already passed [ChallengeValidator.validate] (envelope, mechanic contract,
/// element bounds, resolvability) — this file does not re-check any of that,
/// it only interprets an already-trustworthy proposal into tap/hold/sequence
/// behaviour.
///
/// Per-[AiAction] judging is modeled on the closest existing scripted
/// pattern in `lib/challenges/` (documented per case below) — the proposal
/// schema (one [CorrectAnswer], a flat [AiElement] list, no timeline events)
/// doesn't fully capture every scripted template's richness, so these are
/// deliberate simplifications, not 1:1 ports. Logged to
/// `docs/Meta/Decision Log.md` (search "generated challenge runtime").
///
/// This file is PURE DART: no Flutter imports.
library;

import 'dart:math';

import '../challenges/base.dart';
import '../core/challenge.dart';
import '../i18n/app_locale.dart';
import 'challenge_vocabulary.dart';
import 'generated_challenge.dart';

/// Builds the playable, provenance-tagged wrapper the [ChallengeProvider]
/// seam returns. [locale] drives which of the proposal's per-locale
/// [ChallengeProposal.failLine] entries is shown on failure.
GeneratedChallenge buildFromProposal(
  ChallengeProposal proposal, {
  AppLocale locale = AppLocale.en,
}) {
  final params = ChallengeParams(
    level: proposal.difficulty.level,
    rng: Random(proposal.seed == 0 ? 1 : proposal.seed),
    speed: 1.0,
    locale: locale,
  );
  return GeneratedChallenge(
    challenge: GeneratedChallengeRuntime(proposal, params),
    source: 'ai',
    id: proposal.id,
    seed: proposal.seed,
  );
}

/// The generic [Challenge] every AI proposal renders through — one runtime
/// for all nine [[AI Challenge Generation]] mechanics, dispatching on
/// [MechanicRef.action] rather than shipping a class per mechanic the way
/// `lib/challenges/` does for scripted templates.
class GeneratedChallengeRuntime extends BaseChallenge {
  GeneratedChallengeRuntime(this.proposal, ChallengeParams params)
      : action = AiAction.parse(proposal.mechanic.action) ?? AiAction.tap,
        _correctId = proposal.correctAnswer.elementId,
        _orderedIds = [for (final e in proposal.elements) e.id],
        _tapGoal = _tapUntilStopGoal(proposal),
        super(
          params,
          id: proposal.id,
          tag: proposal.mechanicContract?.tag ?? ChallengeTag.trick,
          duration: Duration(milliseconds: proposal.difficulty.timeLimitMs),
        ) {
    instruction = proposal.instruction;
    layout = _layoutFor(proposal.elements.length);
    targets = [
      for (final e in proposal.elements)
        TargetSpec(
          id: e.id,
          label: e.label,
          color: e.color?.toGameColor() ?? GameColor.slate,
          shape: e.shape?.toTargetShape() ?? TargetShape.rect,
          scale: e.scale,
          rotation: e.rotation,
          dx: e.dx,
          dy: e.dy,
          opacity: e.opacity,
          hidden: e.hidden,
        ),
    ];
    if (action == AiAction.tapUntilStop) {
      tapCounter = '0 / $_tapGoal';
    }
  }

  final ChallengeProposal proposal;
  final AiAction action;

  /// The proposal's one named element — meaning depends on [action]: the
  /// element to tap for `tap`/`colorPick`, the one to avoid for `donot_tap`,
  /// the one to hold for `hold`, the one excluded from `tap_many`'s "tap
  /// every other one," and the tap target for `tap_until_stop`.
  final String _correctId;

  /// Element order doubles as the required tap order for `tap_sequence`
  /// (mirrors `OrderChallenge` — the closest scripted "tap in order" shape;
  /// the proposal schema has no separate sequence field).
  final List<String> _orderedIds;

  /// `tap_until_stop`'s goal isn't in the schema (no timeline events beyond
  /// `difficulty`) — reuses the scripted `SpamTapsChallenge.build` formula
  /// so pacing feels the same as the equivalent hand-authored template.
  final int _tapGoal;

  int _sequenceStep = 0;
  int _tapCount = 0;
  final Set<String> _tappedSafe = {};
  bool _holding = false;

  static int _tapUntilStopGoal(ChallengeProposal p) =>
      6 + min(6, p.difficulty.level ~/ 5);

  static ChallengeLayout _layoutFor(int count) {
    if (count <= 1) return ChallengeLayout.single;
    if (count == 2) return ChallengeLayout.row;
    return ChallengeLayout.grid2x2;
  }

  /// The proposal's own fail line, in [ChallengeParams.locale] — keyed by
  /// ISO code (`"en"`), matching every existing `ChallengeProposal.failLine`
  /// fixture and the v1 English-only generation path ([[AI Challenge
  /// Generation]]). Falls back to the native display name (in case a future
  /// proposal ships that shape instead), then whatever the proposal shipped,
  /// then the scripted generic line.
  String get _failLine =>
      proposal.failLine[params.locale.code] ??
      proposal.failLine[params.locale.nativeName] ??
      (proposal.failLine.isNotEmpty
          ? proposal.failLine.values.first
          : params.tr('common.too_slow'));

  @override
  void onTap(TapInfo tap, ChallengeHost host) {
    switch (action) {
      case AiAction.tap:
      case AiAction.colorPick:
        _onSingleTarget(tap, host);
      case AiAction.doNotTap:
        _onAvoid(tap, host);
      case AiAction.hold:
        _onHold(tap, host);
      case AiAction.tapMany:
        _onTapAllBut(tap, host);
      case AiAction.tapSequence:
        _onSequence(tap, host);
      case AiAction.tapUntilStop:
        _onUntilStop(tap, host);
    }
  }

  /// `tap` / `color_pick`: a single named target wins ([[AI Challenge
  /// Generation]] `tap_true_color`, `tap_missing_color`, `tap_second_order`)
  /// — mirrors the many scripted `TapTargetChallenge` builders.
  void _onSingleTarget(TapInfo tap, ChallengeHost host) {
    if (tap.kind != TapKind.down || tap.isBackground) return;
    if (tap.targetId == _correctId) {
      host.pass();
    } else {
      host.fail(reason: _failLine);
    }
  }

  /// `donot_tap` (`dont_tap_odd`): the named element is the one to avoid;
  /// tapping any other real target wins. Mirrors `buildDontTapColor` — an
  /// active "tap something safe" challenge, not a do-nothing one (that's
  /// the unrelated scripted `dont_tap`/`DontTapChallenge`).
  void _onAvoid(TapInfo tap, ChallengeHost host) {
    if (tap.kind != TapKind.down || tap.isBackground) return;
    if (tap.targetId == _correctId) {
      host.fail(reason: _failLine);
    } else {
      host.pass();
    }
  }

  /// `hold` (`hold_true_color`): hold the named target through the whole
  /// duration. Mirrors `HoldButtonChallenge` — releasing early, or pressing
  /// the wrong target, fails immediately.
  void _onHold(TapInfo tap, ChallengeHost host) {
    switch (tap.kind) {
      case TapKind.down:
        if (tap.isBackground || tap.targetId != _correctId) {
          host.fail(reason: _failLine);
          return;
        }
        _holding = true;
        host.invalidate();
      case TapKind.up:
        if (_holding) {
          _holding = false;
          host.fail(reason: _failLine);
        }
    }
  }

  /// `tap_many` (`tap_every_but`): tap every element except the named
  /// (excluded) one; tapping the excluded one fails immediately. Mirrors
  /// `buildIgnoreNext`/`buildDontTapColor`'s "all but one" correct set.
  void _onTapAllBut(TapInfo tap, ChallengeHost host) {
    if (tap.kind != TapKind.down || tap.isBackground) return;
    if (tap.targetId == _correctId) {
      host.fail(reason: _failLine);
      return;
    }
    _tappedSafe.add(tap.targetId!);
    if (_tappedSafe.length >= _orderedIds.length - 1) {
      host.pass();
    } else {
      host.invalidate();
    }
  }

  /// `tap_sequence` (`tap_second_order`, `sequence_grow_remember`): tap
  /// every element in the order the proposal listed them. Mirrors
  /// `OrderChallenge` (`tap_in_order`) — the closest scripted "walk a fixed
  /// order" shape.
  void _onSequence(TapInfo tap, ChallengeHost host) {
    if (tap.kind != TapKind.down || tap.isBackground) return;
    final wanted = _orderedIds[_sequenceStep];
    if (tap.targetId != wanted) {
      host.fail(reason: _failLine);
      return;
    }
    _sequenceStep++;
    if (_sequenceStep >= _orderedIds.length) {
      host.pass();
    } else {
      host.invalidate();
    }
  }

  /// `tap_until_stop` (`spam_until_stop`): tap the named target until
  /// [_tapGoal] is reached. Mirrors `SpamTapsChallenge`.
  void _onUntilStop(TapInfo tap, ChallengeHost host) {
    if (tap.kind != TapKind.down) return;
    if (tap.isBackground || tap.targetId != _correctId) return;
    _tapCount++;
    tapCounter = '$_tapCount / $_tapGoal';
    if (_tapCount >= _tapGoal) {
      host.pass();
    } else {
      host.invalidate();
    }
  }

  @override
  void onTimeout(ChallengeHost host) {
    if (action == AiAction.hold && _holding) {
      host.pass();
    } else {
      host.fail(reason: _failLine);
    }
  }
}
