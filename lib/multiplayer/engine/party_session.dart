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

import '../../core/challenge.dart';
import '../networking/party_transport.dart';
import '../protocol/protocol.dart';
import 'party_challenge_runner.dart';
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

  /// Drives the open round's [Challenge] once it's GO — see the
  /// design-change note on [PlayerAction] in protocol.dart. Owned here
  /// (not by the UI) so it runs, and tests, headless like the rest of this
  /// class.
  PartyChallengeRunner? _runner;

  /// The most recent input forwarded to the runner, kept only so the
  /// eventual verdict has *something* structural to report alongside it —
  /// informational on the wire, never judged by the host anymore.
  TapInfo? _lastTap;

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

  /// Announces this phone's on-device model availability, once, for the
  /// host's AI Director election ([[Multiplayer AI Director]]). Thin send
  /// only — deciding *when* to call this (and with what real
  /// `computeRank`/`batteryPercent`) is Phase 8's `PartyAiDirector`, not
  /// this session.
  void sendAiCapabilities({
    required bool aiAvailable,
    int computeRank = 0,
    int batteryPercent = 100,
  }) {
    _send(AiCapabilities(
      aiAvailable: aiAvailable,
      computeRank: computeRank,
      batteryPercent: batteryPercent,
    ));
  }

  /// Sends a validated AI-authored round for the host to relay, when this
  /// phone is the elected Director. Thin send only — Phase 8 decides when.
  void sendAiRoundProposal({
    required String roundId,
    required Map<String, Object?> proposal,
  }) {
    _send(AiRoundProposal(roundId: roundId, proposal: proposal));
  }

  /// Sends a validated AI commentary line for the host to relay, when this
  /// phone is the elected Director. Thin send only — Phase 8 decides when.
  void sendAiCommentaryProposal({
    required String kind,
    required String roundId,
    required String text,
  }) {
    _send(AiCommentaryProposal(kind: kind, roundId: roundId, text: text));
  }

  /// Elapsed time on the open round's runner, for [PartyController] to stamp
  /// on a [TapInfo] — null before GO or once the round has closed.
  Duration? get runnerElapsed => _runner?.elapsed;

  /// Forwards one tap to the open round's [PartyChallengeRunner] — a no-op
  /// before GO, after the runner has already settled, or with no round
  /// open. This is the only input entry point `PartyController` needs;
  /// judging and sending the resulting `PLAYER_ACTION` both happen here,
  /// off the runner's verdict.
  void submitTap(TapInfo info) {
    _lastTap = info;
    _runner?.tap(info);
  }

  /// Submits input for the open round, along with the client's own verdict
  /// — computed by [PartyChallengeRunner] replaying the same [Challenge]
  /// single-player uses. The host trusts [correct]/[reason]/[note] directly
  /// (see the design-change note on [PlayerAction]); it still owns
  /// round/duplicate/timing validation, just not content judging.
  void sendAction(
    PartyAction action, {
    required bool correct,
    String? reason,
    String? note,
  }) {
    final round = state.round;
    if (round == null || !state.inGame) return;
    _send(
      PlayerAction(
        playerId: state.selfClientId,
        roundId: round.id,
        action: action,
        correct: correct,
        reason: reason,
        note: note,
        clientTimestampMs: 0,
      ),
    );
  }

  /// Advances the open round's runner to absolute time [elapsed] since GO —
  /// call this from a real per-frame `Ticker` in production
  /// (`mp_game_screen.dart`, exactly like `game_screen.dart` drives
  /// `GameEngine.tick`); a test can call it directly instead of waiting on
  /// real time, the same way `FakePartyClock.advance` stands in for the
  /// host's clock. A no-op before GO or once the round has closed.
  void tick(Duration elapsed) => _runner?.tick(elapsed);

  void _startRunner(PartyRound round) {
    _lastTap = null;
    _runner = PartyChallengeRunner(
      round.challenge,
      onInvalidate: _emitState,
      onVerdict: (verdict) {
        final tap = _lastTap;
        sendAction(
          tap == null
              ? const PartyAction.tap()
              : PartyAction.tap(targetId: tap.targetId, index: tap.index),
          correct: verdict.correct,
          reason: verdict.reason,
          note: verdict.note,
        );
      },
    );
  }

  void _stopRunner() {
    _runner = null;
    _lastTap = null;
  }

  Future<void> dispose() async {
    _stopRunner();
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
        if (round.isGo) _startRunner(round);
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
        _stopRunner();
        state.round = null;
        if (state.phase == PartyPhase.round) state.phase = PartyPhase.playing;
        _emitState();
        _events.add(PartyRoundEndEvent(message));

      case PlayerDisconnected():
        _events.add(PartyPlayerDisconnectedEvent(message));

      case PlayerReconnected():
        _events.add(PartyPlayerReconnectedEvent(message));

      case PlayerEliminated():
        // A player eliminated on the very first round they ever play has no
        // `PlayerStanding` yet — `RoomHost`/`PartyHostReference` broadcast
        // PLAYER_ELIMINATED before that round's PLAYER_SCORE, so `standings`
        // is still empty for them at this point. Silently dropping the flag
        // here (the old `if (standing != null)` guard) meant the very next
        // PLAYER_SCORE created a fresh entry defaulting `eliminated: false`,
        // permanently losing it — caught by
        // test/multiplayer/round_sync_test.dart's "no downtime" auto-close
        // tests eliminating a seat on round 1. Create the entry instead of
        // skipping it so the immediately-following PLAYER_SCORE's
        // `existing?.eliminated ?? false` sees it.
        final standing = state.standings[message.playerId];
        if (standing != null) {
          standing.eliminated = true;
        } else {
          state.standings[message.playerId] = PlayerStanding(
            playerId: message.playerId,
            eliminated: true,
          );
        }
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

      case AiDirectorAssignment():
        state.aiDirectorPeerId = message.directorPeerId;
        _emitState();
        _events.add(PartyDirectorAssignedEvent(message));

      case AiChallengeRound():
        final challenge = buildPartyChallengeFromAiRound(message);
        if (challenge == null) {
          state.lastError = const PartyError(
            code: 'BAD_AI_PROPOSAL',
            detail: 'the relayed AI round could not be parsed',
          );
          _emitState();
          _events.add(PartyErrorEvent(state.lastError!));
        } else {
          state.round = PartyRound(
            id: message.roundId,
            challenge: challenge,
            startAt: message.startAt,
            duration: Duration(milliseconds: message.durationMs),
          );
          state.phase = PartyPhase.round;
          state.roundCount += 1;
          state.privateResult = null;
          state.lastAggregate = null;
          _emitState();
        }
        _events.add(PartyAiChallengeRoundEvent(message));

      case AiCommentary():
        state.lastAiCommentary = message;
        _emitState();
        _events.add(PartyAiCommentaryEvent(message));

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