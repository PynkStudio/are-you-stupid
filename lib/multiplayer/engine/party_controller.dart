/// Maps controller (UI) input to `PLAYER_ACTION`s for the open round.
///
/// The controller is thin on purpose — it never judges; it records what the
/// player did and hands it to the session, which submits it to the host. The
/// host compares against its own canonical challenge ([[Multiplayer
/// Challenges]]).
library;

import '../../core/challenge.dart';
import '../protocol/protocol.dart';
import 'party_session.dart';

/// Audible/haptic-safe tap: reads the open round's [ChallengeView] to attach
/// the visual index, then lets [PartySession] decide whether to send.
class PartyController {
  PartyController(this.session);

  final PartySession session;

  /// A tap landed on the target with global id [TargetSpec.id].
  void onTargetTap(TargetSpec target) {
    final round = session.state.round;
    if (round == null) return;
    int indexOf = -1;
    final targets = round.view.targets;
    for (var i = 0; i < targets.length; i++) {
      if (targets[i].id == target.id) {
        indexOf = i;
        break;
      }
    }
    if (indexOf < 0) {
      session.sendAction(PartyAction.tap(targetId: target.id));
      return;
    }
    session.sendAction(
      PartyAction.tap(targetId: target.id, index: indexOf),
    );
  }

  /// A tap landed on the background (no target).
  void onBackgroundTap() {
    session.sendAction(const PartyAction.tap());
  }

  /// Remaining-count input for counting challenges (absent until supported).
  void onCountCommitted(int count) {
    session.sendAction(PartyAction.count(count));
  }
}