/// Maps controller (UI) input to taps for the open round's
/// [PartyChallengeRunner], owned by [PartySession].
///
/// The controller stays thin: it resolves *which* target got tapped (the
/// renderer only knows ids; the runner's [Challenge] wants a visual index
/// too for position-based challenges like "TAP LEFT") and hands off a
/// [TapInfo]. Judging happens inside the session's runner, not here — see
/// the design-change note on `PlayerAction` in `../protocol/protocol.dart`.
library;

import '../../core/challenge.dart';
import 'party_session.dart';
import 'party_state.dart';

class PartyController {
  PartyController(this.session);

  final PartySession session;

  /// A tap landed on the target with global id [TargetSpec.id].
  void onTargetTap(TargetSpec target) {
    final round = session.state.round;
    if (round == null) return;
    final targets = round.view.targets;
    final indexOf = targets.indexWhere((t) => t.id == target.id);
    session.submitTap(TapInfo(
      targetId: target.id,
      elapsed: _elapsed(round),
      index: indexOf < 0 ? null : indexOf,
    ));
  }

  /// A tap landed on the background (no target).
  void onBackgroundTap() {
    final round = session.state.round;
    if (round == null) return;
    session.submitTap(TapInfo(targetId: null, elapsed: _elapsed(round)));
  }

  Duration _elapsed(PartyRound round) =>
      session.runnerElapsed ?? Duration.zero;
}
