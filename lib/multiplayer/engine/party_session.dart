/// Client lifecycle: consumes the protocol wire and drives [PartyState].
///
/// One [PartySession] lives per controller connection. It owns the transport,
/// decodes every line inbound ([Decoded] via [PartyProtocol.decode]), applies
/// the forward-tolerant rules (unknown `type`/fields ignored — [[Multiplayer
/// Protocol]]), and rebuilds [PartyState] + a [PartyEvent] stream for the UI.
///
/// Pure Dart: no Flutter imports ([[Multiplayer Client (Mobile)]]).
library;

import 'dart:async';

import '../networking/party_transport.dart';
import '../protocol/protocol.dart';
import 'party_state.dart';

/// A controller connection whose state machine mirrors [[Multiplayer Protocol]].
class PartySession {
  PartySession({
    required PartyTransport transport,
    required this.appName,
    required this.appVersion,
  })  : _transport = transport,
        state = PartyState(),
        _events = StreamController<PartyEvent>.broadcast(sync: true),
        _stateStream = StreamController<PartyState>.broadcast(sync: true) {
    _sub = _transport.inbound.listen(_onLine, onDone: _onTransportDone);
  }

  final PartyTransport _transport;
  final String appName;
  final String appVersion;

  final PartyState state;
  late final StreamSubscription<String> _sub;

  final StreamController<PartyEvent> _events;
  final StreamController<PartyState> _stateStream;

  /// Typed protocol events (for navigation and one-shot feedback).
  Stream<PartyEvent> get events => _events.stream;

  /// Immutable snapshots of [state] after every change.
  Stream<PartyState> get states => _stateStream.stream;

  void _emitState() => _stateStream.add(state);

  void _send(PartyMessage message) => _transport.send(PartyProtocol.encode(message));

  /// Handshake; idempotent so a reconnected session can call it again.
  void connect() {
    state.phase = PartyPhase.handshaking;
    _emitState();
    _send(Hello(appName: appName, appVersion: appVersion));
  }

  void joinRoom({required String playerName, required String emoji}) {
    _send(JoinRoom(playerName: playerName, emoji: emoji));
  }

  void setReady(bool ready) {
    _send(PlayerReady(playerId: state.selfClientId, ready: ready));
  }

  void leaveRoom() {
    _send(LeaveRoom());
  }

  /// Submits input for the open round. The host judges from its own clock and
  /// canonical challenge; the client never processes its own correctness.
  void sendAction(PartyAction action) {
    final round = state.round;
    if (round == null || !state.inGame) return;
    _send(
      PlayerAction(
        playerId: state.selfClientId,
        roundId: round.id,
        action: action,
        clientTimestampMs: 0,
      ),
    );
  }

  Future<void> dispose() async {
    await _sub.cancel();
    await _transport.close();
    await _events.close();
    await _stateStream.close();
  }

  void _onTransportDone() {
    state.phase = PartyPhase.disconnected;
    _emitState();
  }

  void _onLine(String line) {
    switch (PartyProtocol.decode(line)) {
      case DecodedOk(:final message):
        _apply(message);
      case DecodedMalformed(:final reason):
        state.lastError = PartyError(code: 'BAD_MESSAGE', detail: 'malformed: $reason');
        _emitState();
        _events.add(PartyErrorEvent(state.lastError!));
      case DecodedUnknownType():
        break; // forward-tolerant: unknown types are ignored.
    }
  }

  void _apply(PartyMessage message) {
    switch (message) {
      case HostHello():
        state.host = message;
        state.phase = PartyPhase.lobby;
        _emitState();
        _events.add(PartyHandshakeEvent(message));

      case Rejected():
        state.phase = PartyPhase.rejected;
        state.rejected = message;
        _emitState();
        _events.add(PartyRejectedEvent(message));

      case PlayerJoined():
        state.roomId = message.roomId;
        state.selfClientId = message.selfClientId;
        state.players = message.players;
        _emitState();
        _events.add(PartyJoinedEvent(message));

      case PlayerLeave():
        state.players = state.players.where((p) => p.playerId != message.playerId).toList();
        _emitState();
        _events.add(PartyPlayerLeftEvent(message));

      case PlayerReadyRoster():
        state.players = message.players;
        _emitState();
        _events.add(PartyRosterEvent(message));

      case StartGame():
        state.mode = message.mode;
        state.config = message.config;
        state.roundCount = 0;
        state.phase = PartyPhase.ready;
        _emitState();
        _events.add(PartyGameStartedEvent(message));

      case RoundStart():
        state.round = PartyRound(
          id: message.roundId,
          challenge: buildPartyChallenge(message),
          startAt: message.startAt,
          duration: Duration(milliseconds: message.durationMs),
          challengeId: message.challengeId,
          seed: message.seed,
          level: (message.config['level'] as int?) ?? 1,
        );
        state.phase = PartyPhase.round;
        state.roundCount += 1;
        state.privateResult = null;
        state.lastAggregate = null;
        _emitState();
        _events.add(PartyRoundStartedEvent(message));

      case RoundCountdown():
        final round = state.round;
        if (round == null || round.id != message.roundId) return;
        round.countdown = _parseCountdown(message.state);
        _emitState();
        _events.add(PartyCountdownEvent(message));

      case RoundResult():
        state.privateResult = message;
        _emitState();
        _events.add(PartyRoundResultEvent(message));

      case RoundResults():
        state.lastAggregate = message.results;
        _emitState();
        _events.add(PartyAggregateEvent(message));

      case RoundEnd():
        state.round = null;
        if (state.phase == PartyPhase.round) state.phase = PartyPhase.playing;
        _emitState();
        _events.add(PartyRoundEndEvent(message));

      case PlayerDisconnected():
        _events.add(PartyPlayerDisconnectedEvent(message));

      case PlayerReconnected():
        _events.add(PartyPlayerReconnectedEvent(message));

      case PlayerEliminated():
        final standing = state.standings[message.playerId];
        if (standing != null) standing.eliminated = true;
        if (state.selfClientId == message.playerId) {
          state.phase = PartyPhase.playing; // watches from the sidelines.
        }
        _emitState();
        _events.add(PartyEliminatedEvent(message));

      case PlayerScore():
        final existing = state.standings[message.playerId];
        state.standings[message.playerId] = PlayerStanding(
          playerId: message.playerId,
          score: message.score,
          standing: message.standing,
          eliminated: existing?.eliminated ?? false,
        );
        _emitState();
        _events.add(PartyScoreEvent(message));

      case GameEnd():
        state.phase = PartyPhase.gameEnded;
        state.gameEnd = message;
        _emitState();
        _events.add(PartyGameEndEvent(message));

      case PartyError():
        state.lastError = message;
        _emitState();
        _events.add(PartyErrorEvent(message));

      default:
        break; // forward-tolerant.
    }
  }

  static PlayerCountdown _parseCountdown(String state) => switch (state) {
        'READY' => PlayerCountdown.ready,
        'GO' => PlayerCountdown.go,
        _ => PlayerCountdown.waiting,
      };
}