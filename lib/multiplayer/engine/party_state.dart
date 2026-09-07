/// Client mirror of the host's authoritative state — pure Dart.
///
/// Everything a view needs to render a controller screen lives here: lobby
/// roster, the current round (locally rebuilt from the host's
/// `{ challengeId, seed }` via `buildFromSeed`, exactly like every other
/// phone — [[Multiplayer Challenges]]), private results, scores, winner.
///
/// The client never *decides* anything it mirrors; it only renders. This file
/// never imports Flutter so the whole engine is headless-testable
/// ([[Multiplayer Client (Mobile)]], [[Multiplayer Development]]).
library;

import '../../challenges/registry.dart';
import '../../core/challenge.dart';
import '../protocol/protocol.dart';

/// Where the flow stands, mirrored from the messages received.
enum PartyPhase {
  /// Sent `HELLO`, waiting for `HOST_HELLO`.
  handshaking,

  /// In the lobby, can toggle ready.
  lobby,

  /// Ready and waiting for `START_GAME`.
  ready,

  /// A match is running but no round is open.
  playing,

  /// A round is open; input goes to the host.
  round,

  /// `GAME_END` received; render results + share.
  gameEnded,

  /// `REJECTED` (version/policy mismatch); connection should close.
  rejected,

  /// The connection dropped (peer gone or transport closed).
  disconnected,
}

/// One open round as the client sees it.
class PartyRound {
  PartyRound({
    required this.id,
    required this.challenge,
    required this.startAt,
    required this.duration,
    this.challengeId = '',
    this.seed = 0,
    this.level = 1,
  });

  final String id;
  final Challenge challenge;
  final int startAt;
  final Duration duration;

  /// The canonical build tuple, kept so a client can re-derive the view on
  /// demand (e.g. a test recomputing the correct answer from `seed`).
  final String challengeId;
  final int seed;
  final int level;

  PlayerCountdown _countdown = PlayerCountdown.waiting;

  String get countdownState => _countdown.wire;

  bool get isGo => _countdown == PlayerCountdown.go;

  set countdown(PlayerCountdown value) => _countdown = value;

  /// The canonical view for this round (same on every end).
  ChallengeView get view => challenge.view;
}

/// The `ROUND_COUNTDOWN` state, per [[Multiplayer Protocol]].
enum PlayerCountdown {
  /// `READY` — target about to be shown.
  ready('READY'),

  /// `GO` — round is live.
  go('GO'),

  /// No countdown frame received yet for this round.
  waiting('');

  const PlayerCountdown(this.wire);
  final String wire;
}

/// A live standings row for one player.
class PlayerStanding {
  PlayerStanding({
    required this.playerId,
    this.score = 0,
    this.lives,
    this.standing = 0,
    this.eliminated = false,
  });

  final String playerId;
  int score;
  int? lives;
  int standing;
  bool eliminated;

  PlayerStanding copyWith({
    int? score,
    int? lives,
    int? standing,
    bool? eliminated,
  }) =>
      PlayerStanding(
        playerId: playerId,
        score: score ?? this.score,
        lives: lives ?? this.lives,
        standing: standing ?? this.standing,
        eliminated: eliminated ?? this.eliminated,
      );
}

/// The complete image a controller screen renders. Rebuilt from each received
/// message; views watch [PartySession.states].
class PartyState {
  PartyState();

  PartyPhase phase = PartyPhase.handshaking;

  HostHello? host;
  String roomId = '';
  String selfClientId = '';

  /// Full roster snapshot (name/emoji/ready).
  List<PlayerInfo> players = const [];

  GameMode mode = GameMode.stupidBattle;
  Map<String, Object?> config = const {};

  PartyRound? round;

  RoundResult? privateResult;
  List<PlayerRoundResult>? lastAggregate;

  /// playerId → standing, rebuilt after each round.
  final Map<String, PlayerStanding> standings = {};

  GameEnd? gameEnd;
  Rejected? rejected;
  PartyError? lastError;

  bool get inGame => phase == PartyPhase.playing || phase == PartyPhase.round;

  PlayerInfo? get self => _firstById(selfClientId);

  PlayerInfo? _firstById(String id) {
    for (final p in players) {
      if (p.playerId == id) return p;
    }
    return null;
  }

  /// The challenge id for the open round, if any.
  String? get currentChallengeId => round?.challenge.id;

  /// The canonical view to render this round, or null.
  ChallengeView? get currentView => round?.view;

  int roundCount = 0;
  int get totalRounds => (config['totalRounds'] as int?) ?? 20;
}

/// Raw events the session emits, mirroring the protocol messages it decodes.
/// Views may subscribe for one-shot navigation (flash, result, share).
sealed class PartyEvent {
  const PartyEvent();
}

class PartyHandshakeEvent extends PartyEvent {
  const PartyHandshakeEvent(this.hello);
  final HostHello hello;
}

class PartyRejectedEvent extends PartyEvent {
  const PartyRejectedEvent(this.rejected);
  final Rejected rejected;
}

class PartyJoinedEvent extends PartyEvent {
  const PartyJoinedEvent(this.joined);
  final PlayerJoined joined;
}

class PartyRosterEvent extends PartyEvent {
  const PartyRosterEvent(this.roster);
  final PlayerReadyRoster roster;
}

class PartyPlayerLeftEvent extends PartyEvent {
  const PartyPlayerLeftEvent(this.leave);
  final PlayerLeave leave;
}

class PartyGameStartedEvent extends PartyEvent {
  const PartyGameStartedEvent(this.started);
  final StartGame started;
}

class PartyRoundStartedEvent extends PartyEvent {
  const PartyRoundStartedEvent(this.roundStart);
  final RoundStart roundStart;
}

class PartyCountdownEvent extends PartyEvent {
  const PartyCountdownEvent(this.countdown);
  final RoundCountdown countdown;
}

class PartyRoundResultEvent extends PartyEvent {
  const PartyRoundResultEvent(this.result);
  final RoundResult result;
}

class PartyAggregateEvent extends PartyEvent {
  const PartyAggregateEvent(this.results);
  final RoundResults results;
}

class PartyPlayerDisconnectedEvent extends PartyEvent {
  const PartyPlayerDisconnectedEvent(this.disconnected);
  final PlayerDisconnected disconnected;
}

class PartyPlayerReconnectedEvent extends PartyEvent {
  const PartyPlayerReconnectedEvent(this.reconnected);
  final PlayerReconnected reconnected;
}

class PartyEliminatedEvent extends PartyEvent {
  const PartyEliminatedEvent(this.eliminated);
  final PlayerEliminated eliminated;
}

class PartyScoreEvent extends PartyEvent {
  const PartyScoreEvent(this.score);
  final PlayerScore score;
}

class PartyGameEndEvent extends PartyEvent {
  const PartyGameEndEvent(this.end);
  final GameEnd end;
}

class PartyErrorEvent extends PartyEvent {
  const PartyErrorEvent(this.error);
  final PartyError error;
}

class PartyRoundEndEvent extends PartyEvent {
  const PartyRoundEndEvent(this.end);
  final RoundEnd end;
}

/// Builds the canonical local challenge for a round, exactly as every other
/// clip does, from the host's `ROUND_START` tuple.
Challenge buildPartyChallenge(RoundStart start) {
  final level = (start.config['level'] as int?) ?? 1;
  return buildFromSeed(
    challengeId: start.challengeId,
    seed: start.seed,
    level: level,
  );
}