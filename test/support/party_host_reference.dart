/// In-process host reference for the multiplayer simulation.
///
/// This is the authority of the harness: it speaks the exact wire of
/// [[Multiplayer Protocol]] over [PartyTransport]s — the same contract the
/// future Swift tvOS host will use — but lives in `test/support` because
/// shipping the authority in the Flutter app would defeat the design (the real
/// host is the Swift app on the TV, [[Multiplayer Host (tvOS)]]).
///
/// It judges rounds headlessly:
///  1. rebuilds the canonical challenge per player from `{challengeId, seed}`
///     via `buildFromSeed` (the same deterministic tuple every phone builds);
///  2. replays the clock to the action's elapsed, applies the player's input,
///     flushes the settle window (exact-taps grace) and finally `onTimeout`;
///  3. reports `correct` / `reason` exactly like the solo engine would.
///
/// Everything is clocked by a [FakePartyClock] so tests advance time
/// deterministically — no sleeps ([[Multiplayer Development]]). Rounds are
/// never auto-ticked: the test calls `startRound`, advances the clock, sends
/// actions, then `completeRound`.
library;

import 'dart:async';
import 'dart:convert';

import 'package:are_you_stupid/challenges/registry.dart';
import 'package:are_you_stupid/core/challenge.dart';
import 'package:are_you_stupid/core/challenge_generator.dart';
import 'package:are_you_stupid/i18n/app_locale.dart';
import 'package:are_you_stupid/multiplayer/networking/party_transport.dart';
import 'package:are_you_stupid/multiplayer/protocol/protocol.dart';

import 'fake_host.dart' as judge_support;

/// One connected end, before (or without) a seat.
class _Conn {
  _Conn(this.transport);
  final PartyTransport transport;
  late final StreamSubscription<String> sub;
}

/// A seated player.
class _Seat {
  _Seat({
    required this.playerId,
    required this.gameName,
    required this.emoji,
    required this.joinOrder,
  });

  final String playerId;
  final String gameName;
  final String emoji;
  final int joinOrder;

  bool ready = false;
  bool alive = true;
  late int lives;
  int score = 0;
  _Conn? conn;
  int? disconnectedAtMs;
  PartyAction? pendingAction;
  int? actionElapsedMs;
}

/// One open round as the host drives it.
class _Round {
  _Round({
    required this.id,
    required this.challengeId,
    required this.seed,
    required this.startAt,
    required this.duration,
    required this.level,
  });

  final String id;
  final String challengeId;
  final int seed;
  final int startAt;
  final Duration duration;
  final int level;

  bool ended = false;
  final Map<String, PlayerRoundResult> judged = {};
}

/// The result of judging one player's input.
class _Judged {
  _Judged({required this.correct, this.note, this.reason});
  final bool correct;
  final String? note;
  final String? reason;
}

const _defaultLives = 3;
const _defaultBattleRounds = 20;
const _tapStep = Duration(milliseconds: 16);

/// The in-process reference host.
///
/// Create one, `attachClient(serverTransport)` for every player connection,
/// then drive game flow: `startGame`, `startRound`, `completeRound`. Actions
/// are judged as they arrive; timeouts are judged at `completeRound`.
class PartyHostReference {
  PartyHostReference({
    this.hostName = 'ARE YOU STUPID?',
    this.roomCode = 'AYS',
    this.maxPlayers = 8,
    this.lives = _defaultLives,
    this.battleRounds = _defaultBattleRounds,
    this.speedBonus = false,
    this.graceWindowMs = 15000,
    required FakePartyClock clock,
  })  : _clock = clock,
        _generator = ChallengeGenerator(templates: kChallengeTemplates);

  final String hostName;
  final String roomCode;
  final int maxPlayers;
  final int lives;
  final int battleRounds;
  final bool speedBonus;
  final int graceWindowMs;

  final FakePartyClock _clock;
  final ChallengeGenerator _generator;

  final List<_Conn> _conns = [];
  final Map<String, _Seat> _seats = {};
  final List<String> _joinOrder = [];

  GameMode _mode = GameMode.stupidBattle;
  bool _inGame = false;
  _Round? _round;
  int _roundIndex = 0;
  int _nextPlayer = 1;
  int _nextRound = 1;

  int get nowMs => _clock.nowMs;
  FakePartyClock get clock => _clock;
  bool get inGame => _inGame;
  int get seatCount => _seats.length;
  int get aliveCount => _seats.values.where((s) => s.alive).length;
  bool get roundOpen => _round != null && !_round!.ended;
  String? get openRoundId => _round?.id;

  /// Registers a transport as a client connection. The connection is greeted
  /// when it sends `HELLO`.
  void attachClient(PartyTransport transport) {
    final conn = _Conn(transport);
    conn.sub = transport.inbound.listen(
      (line) => _onLine(conn, line),
      onDone: () => _onDisconnected(conn),
    );
    _conns.add(conn);
  }

  Future<void> close() async {
    for (final conn in _conns) {
      await conn.transport.close();
    }
  }

  // ------------------------------------------------------------- gatekeeper

  void _onLine(_Conn conn, String line) {
    int? incomingVersion;
    try {
      final obj = jsonDecode(line);
      if (obj is Map) incomingVersion = obj['protocolVersion'] as int?;
    } catch (_) {
      // Left null; decode below decides malformed.
    }

    final decoded = PartyProtocol.decode(line);
    switch (decoded) {
      case DecodedOk(:final message):
        if (message is Hello &&
            incomingVersion != null &&
            incomingVersion != kProtocolVersion) {
          _send(
            conn,
            Rejected(
              reason: 'protocolVersion $incomingVersion unsupported, '
                  'need $kProtocolVersion',
              ts: nowMs,
            ),
          );
          return;
        }
        _handle(conn, message);
      case DecodedMalformed():
        _send(conn,
            PartyError(code: 'BAD_MESSAGE', detail: 'malformed frame', ts: nowMs));
      case DecodedUnknownType():
        break; // forward-tolerant.
    }
  }

  void _handle(_Conn conn, PartyMessage message) {
    switch (message) {
      case Hello():
        _onHello(conn);
      case JoinRoom():
        _onJoin(conn, message);
      case PlayerReady():
        _onReady(conn, message);
      case LeaveRoom():
        _onLeave(conn);
      case PlayerAction():
        _onAction(conn, message);
      default:
        _send(conn,
            PartyError(code: 'BAD_MESSAGE', detail: 'unexpected ${message.type}', ts: nowMs));
    }
  }

  void _onHello(_Conn conn) {
    _send(
      conn,
      HostHello(
        hostName: hostName,
        roomCode: roomCode,
        maxPlayers: maxPlayers,
        ts: nowMs,
      ),
    );
  }

  void _onJoin(_Conn conn, JoinRoom join) {
    if (_inGame) {
      _tryReconnect(conn, join);
      return;
    }
    if (_seats.length >= maxPlayers) {
      _send(conn,
          PartyError(code: 'ROOM_FULL', detail: 'host is full', ts: nowMs));
      return;
    }
    final seat = _Seat(
      playerId: 'p${_nextPlayer++}',
      gameName: join.playerName,
      emoji: join.emoji,
      joinOrder: _joinOrder.length,
    );
    seat.lives = lives;
    seat.conn = conn;
    _seats[seat.playerId] = seat;
    _joinOrder.add(seat.playerId);
    _send(conn, _joined(seat));
    _broadcastRoster();
  }

  void _tryReconnect(_Conn conn, JoinRoom join) {
    _Seat? candidate;
    for (final seat in _seats.values) {
      if (seat.alive &&
          seat.conn == null &&
          seat.gameName == join.playerName &&
          seat.emoji == join.emoji) {
        candidate = seat;
        break;
      }
    }
    if (candidate == null) {
      _rejectReconnect(conn, join);
      return;
    }
    final since = nowMs - (candidate.disconnectedAtMs ?? nowMs);
    if (since > graceWindowMs) {
      _rejectReconnect(conn, join);
      return;
    }
    candidate.conn = conn;
    candidate.disconnectedAtMs = null;
    // Re-introduce the session to itself: same playerId + roster it had
    // before the drop, so the phone knows who it is again.
    _send(conn, _joined(candidate));
    _broadcastRoster();
    _broadcast(PlayerReconnected(playerId: candidate.playerId, ts: nowMs));
  }

  void _rejectReconnect(_Conn conn, JoinRoom join) {
    _send(
      conn,
      PartyError(
        code: 'ROOM_FULL',
        detail: 'no reconnectable seat for ${join.playerName}',
        ts: nowMs,
      ),
    );
  }

  void _onReady(_Conn conn, PlayerReady ready) {
    final seat = _seatFor(conn);
    if (seat == null) return;
    if (ready.playerId.isNotEmpty && ready.playerId != seat.playerId) {
      _send(conn,
          PartyError(code: 'BAD_MESSAGE', detail: 'wrong playerId', ts: nowMs));
      return;
    }
    seat.ready = ready.ready;
    _broadcastRoster();
  }

  void _onLeave(_Conn conn) {
    final seat = _seatFor(conn);
    if (seat == null) return;
    _removeSeat(seat, reason: 'left');
  }

  // ---------------------------------------------------------------- rounds

  /// Starts a match. Requires ≥2 ready players (the protocol gate).
  void startGame({GameMode mode = GameMode.stupidBattle}) {
    if (_inGame) return;
    final ready = _seats.values.where((s) => s.ready).length;
    if (ready < 2) {
      throw StateError('need >= 2 ready players to start (got $ready)');
    }
    for (final seat in _seats.values) {
      seat.ready = false;
      seat.alive = true;
      seat.score = 0;
      seat.lives = lives;
      seat.pendingAction = null;
      seat.actionElapsedMs = null;
    }
    _mode = mode;
    _inGame = true;
    _roundIndex = 0;
    _broadcast(
      StartGame(
        mode: mode,
        config: {
          if (mode == GameMode.lastStupidStanding) 'lives': lives,
          if (mode == GameMode.stupidBattle) 'totalRounds': battleRounds,
          if (speedBonus) 'speedBonus': true,
        },
        ts: nowMs,
      ),
    );
  }

  /// Opens a round for an explicit tuple (deterministic for tests).
  void startRound({
    required String challengeId,
    required int seed,
    required int level,
  }) {
    _pruneDisconnected();
    final template = templateById(challengeId);
    if (template == null) {
      throw ArgumentError.value(challengeId, 'challengeId', 'unknown template');
    }
    final canonical = buildFromSeed(
      challengeId: challengeId,
      seed: seed,
      level: level,
      locale: AppLocale.en,
    );
    final startAt = nowMs;
    final round = _round = _Round(
      id: 'r${_nextRound++}',
      challengeId: challengeId,
      seed: seed,
      startAt: startAt,
      duration: canonical.duration,
      level: level,
    );
    _roundIndex++;
    _broadcast(
      RoundStart(
        roundId: round.id,
        challengeId: challengeId,
        seed: seed,
        startAt: startAt,
        durationMs: round.duration.inMilliseconds,
        config: {'level': level},
        ts: nowMs,
      ),
    );
    _broadcast(RoundCountdown(
        roundId: round.id, atMs: startAt - 1000, state: 'READY', ts: nowMs));
    _broadcast(
        RoundCountdown(roundId: round.id, atMs: startAt, state: 'GO', ts: nowMs));
    for (final seat in _seats.values) {
      if (seat.alive) {
        seat.pendingAction = null;
        seat.actionElapsedMs = null;
      }
    }
  }

  /// Picks a round like the solo generator and opens it (level-gated, weighted,
  /// no immediate repeat).
  void startRandomRound({required int level}) {
    final chosen = _generator.next(level);
    final seed = nowMs & 0x7fffffff;
    startRound(challengeId: chosen.id, seed: seed, level: level);
  }

  /// Closes the open round: times out anything unanswered, then broadcasts
  /// `ROUND_RESULTS`, score patches, `ROUND_END` and — when the match is
  /// decided — `GAME_END`.
  void completeRound() {
    final round = _round;
    if (round == null || round.ended) return;
    round.ended = true;

    for (final seat in _seats.values) {
      if (!seat.alive) continue;
      final existing = round.judged[seat.playerId];
      if (existing != null) continue;
      final judged = _judgeTimeout(round);
      final result = _result(seat, judged, actionElapsedMs: null);
      round.judged[seat.playerId] = result;
      final conn = seat.conn;
      if (conn != null) {
        _send(
          conn,
          RoundResult(
            roundId: round.id,
            correct: result.correct,
            reason: result.reason,
            scoreDelta: result.scoreDelta,
            actionReceivedMs: null,
            ts: nowMs,
          ),
        );
      }
    }

    _broadcast(
        RoundResults(roundId: round.id, results: round.judged.values.toList(), ts: nowMs));
    _broadcast(RoundEnd(roundId: round.id, ts: nowMs));

    _applyScoring(round);
    _endRoundIfDecided();
  }

  void _onAction(_Conn conn, PlayerAction action) {
    final round = _round;
    if (round == null || round.ended) {
      _send(conn,
          PartyError(code: 'ROUND_CLOSED', detail: 'no open round', ts: nowMs));
      return;
    }
    final seat = _seatFor(conn);
    if (seat == null || seat.playerId != action.playerId) {
      _send(conn,
          PartyError(code: 'BAD_MESSAGE', detail: 'unknown playerId', ts: nowMs));
      return;
    }
    if (!seat.alive) return; // eliminated seats are spectators.
    if (action.roundId != round.id) {
      _send(conn,
          PartyError(code: 'ROUND_CLOSED', detail: 'stale round', ts: nowMs));
      return;
    }
    if (seat.pendingAction != null) {
      _send(conn,
          PartyError(code: 'DUPLICATE_ACTION', detail: 'already submitted', ts: nowMs));
      return;
    }

    final elapsed = nowMs - round.startAt;
    if (elapsed >= round.duration.inMilliseconds) {
      _send(conn,
          PartyError(code: 'ROUND_CLOSED', detail: 'round expired', ts: nowMs));
      return;
    }

    final judged = _judgeInput(round, action, elapsed);
    seat.pendingAction = action.action;
    seat.actionElapsedMs = elapsed;
    final result = _result(seat, judged, actionElapsedMs: elapsed);
    round.judged[seat.playerId] = result;
    _send(
      conn,
      RoundResult(
        roundId: round.id,
        correct: result.correct,
        reason: result.reason,
        scoreDelta: result.scoreDelta,
        actionReceivedMs: nowMs,
        ts: nowMs,
      ),
    );
  }

  // ---------------------------------------------------------------- judging

  Challenge _build(_Round round) => buildFromSeed(
        challengeId: round.challengeId,
        seed: round.seed,
        level: round.level,
        locale: AppLocale.en,
      );

  /// Runs `onTick` from [from] to [to] against a fresh judge; fires
  /// `onTimeout` when the round expires without a decision.
  void _drive(Challenge ch, judge_support.FakeHost host, Duration from,
      Duration to) {
    var t = from;
    while (t < to && !host.settled) {
      t += _tapStep;
      ch.onTick(t, host);
    }
    if (!host.settled && to >= ch.duration) {
      ch.onTimeout(host);
    }
  }

  _Judged _judgeInput(_Round round, PlayerAction message, int elapsedMs) {
    final ch = _build(round);
    final host = judge_support.FakeHost();
    ch.onStart(host);
    final elapsed = Duration(milliseconds: elapsedMs);
    _drive(ch, host, Duration.zero, elapsed);
    if (host.settled) return _pack(host);
    if (message.action.kind == 'count') {
      for (var i = 0; i < (message.action.count ?? 0); i++) {
        if (host.settled) break;
        ch.onTap(judge_support.tapOn('pad', at: elapsed), host);
      }
    } else if (message.action.targetId == null) {
      ch.onTap(judge_support.tapBackground(at: elapsed), host);
    } else {
      ch.onTap(
        judge_support.tapOn(
          message.action.targetId!,
          index: message.action.index ?? 0,
          at: elapsed,
        ),
        host,
      );
    }
    _drive(ch, host, elapsed, ch.duration);
    return _pack(host);
  }

  _Judged _judgeTimeout(_Round round) {
    final ch = _build(round);
    final host = judge_support.FakeHost();
    ch.onStart(host);
    _drive(ch, host, Duration.zero, ch.duration);
    return _pack(host);
  }

  _Judged _pack(judge_support.FakeHost host) {
    if (host.passed) return _Judged(correct: true, note: host.note);
    return _Judged(correct: false, reason: host.reason ?? 'wrong');
  }

  PlayerRoundResult _result(_Seat seat, _Judged judged,
      {required int? actionElapsedMs}) {
    var scoreDelta = 0;
    if (judged.correct && _mode == GameMode.stupidBattle) {
      scoreDelta = 100;
    }
    return PlayerRoundResult(
      playerId: seat.playerId,
      correct: judged.correct,
      reason: judged.correct ? judged.note ?? '' : judged.reason ?? '',
      scoreDelta: scoreDelta,
      reactionMs: actionElapsedMs,
    );
  }

  // ---------------------------------------------------------------- scoring

  void _applyScoring(_Round round) {
    if (_mode == GameMode.lastStupidStanding) {
      for (final seat in _seats.values) {
        if (!seat.alive) continue;
        final r = round.judged[seat.playerId];
        if (r != null && !r.correct) {
          seat.lives -= 1;
          if (seat.lives <= 0) {
            seat.alive = false;
            _broadcast(
                PlayerEliminated(roundId: round.id, playerId: seat.playerId, ts: nowMs));
          }
        }
        _broadcast(PlayerScore(
            playerId: seat.playerId,
            mode: _mode,
            score: seat.score,
            lives: seat.lives,
            standing: _standingFor(seat),
            ts: nowMs));
      }
      return;
    }

    // Battle: point deltas + optional top-3 reaction bonus.
    final correctFast = _correctOrder(round);
    for (var i = 0; i < correctFast.length; i++) {
      final seat = _seat(correctFast[i]);
      if (seat == null) continue;
      var delta = 100;
      if (speedBonus && i < 3) {
        const bonus = [50, 25, 10];
        delta += bonus[i];
      }
      seat.score += delta;
    }
    for (final seat in _seats.values) {
      _broadcast(PlayerScore(
          playerId: seat.playerId,
          mode: _mode,
          score: seat.score,
          standing: _standingFor(seat),
          ts: nowMs));
    }
  }

  List<String> _standings() {
    final order = [..._joinOrder];
    order.sort((a, b) {
      final scoreDiff = _seat(b)!.score.compareTo(_seat(a)!.score);
      if (scoreDiff != 0) return scoreDiff;
      return _seat(a)!.joinOrder.compareTo(_seat(b)!.joinOrder);
    });
    return order;
  }

  int _standingFor(_Seat seat) => _standings().indexOf(seat.playerId) + 1;

  String? _soleSurvivor() {
    for (final seat in _seats.values) {
      if (seat.alive) return seat.playerId;
    }
    return null;
  }

  List<String> _correctOrder(_Round round) {
    final entries = round.judged.entries.where((e) => e.value.correct).toList()
      ..sort((a, b) {
        final ra = a.value.reactionMs;
        final rb = b.value.reactionMs;
        if (ra == null && rb == null) return 0;
        if (ra == null) return 1;
        if (rb == null) return -1;
        return ra.compareTo(rb);
      });
    return [for (final e in entries) e.key];
  }

  void _endRoundIfDecided() {
    if (!_inGame) return;

    if (_mode == GameMode.lastStupidStanding) {
      final alive = aliveCount;
      if (alive <= 1) {
        _finish(winnerId: alive == 1 ? _soleSurvivor() : null);
        return;
      }
    } else if (_roundIndex >= battleRounds) {
      _finish(winnerId: _standings().first);
      return;
    }
  }

  void _finish({String? winnerId}) {
    _inGame = false;
    final standings = _standings();
    _broadcast(
      GameEnd(
        mode: _mode,
        results: [
          for (var i = 0; i < standings.length; i++)
            GameResultEntry(
              playerId: standings[i],
              score: _seat(standings[i])!.score,
              lives: _mode == GameMode.lastStupidStanding
                  ? _seat(standings[i])!.lives
                  : null,
              standing: i + 1,
            ),
        ],
        winnerId: winnerId,
        ts: nowMs,
      ),
    );
  }

  // ---------------------------------------------------------------- wiring

  void _pruneDisconnected() {
    if (!_inGame) return;
    for (final seat in _seats.values.toList()) {
      if (seat.conn != null || !seat.alive) continue;
      final since = nowMs - (seat.disconnectedAtMs ?? nowMs);
      if (since > graceWindowMs) {
        seat.alive = false;
        _removeSeat(seat, reason: 'disconnected');
      }
    }
  }

  void _onDisconnected(_Conn conn) {
    if (!_conns.remove(conn)) return;
    final seat = _seatFor(conn);
    if (seat == null) return; // unseated connection; nothing to do.
    if (!_inGame) {
      _removeSeat(seat, reason: 'disconnected');
      return;
    }
    seat.conn = null;
    seat.disconnectedAtMs = nowMs;
    _broadcast(PlayerDisconnected(playerId: seat.playerId, ts: nowMs));
    _pruneDisconnected();
  }

  void _removeSeat(_Seat seat, {required String reason}) {
    _seats.remove(seat.playerId);
    _joinOrder.remove(seat.playerId);
    _broadcast(PlayerLeave(playerId: seat.playerId, reason: reason, ts: nowMs));
  }

  void _broadcastRoster() {
    _broadcast(
        PlayerReadyRoster(players: [for (final s in _seats.values) _info(s)], ts: nowMs));
  }

  PlayerInfo _info(_Seat seat) => PlayerInfo(
        playerId: seat.playerId,
        playerName: seat.gameName,
        emoji: seat.emoji,
        ready: seat.ready,
      );

  PlayerJoined _joined(_Seat seat) => PlayerJoined(
        selfClientId: seat.playerId,
        roomId: roomCode,
        players: [for (final s in _seats.values) _info(s)],
      );

  _Seat? _seatFor(_Conn conn) {
    for (final seat in _seats.values) {
      if (seat.conn == conn) return seat;
    }
    return null;
  }

  _Seat? _seat(String playerId) => _seats[playerId];

  void _broadcast(PartyMessage message) {
    final wire = PartyProtocol.encode(message);
    for (final conn in _conns) {
      _sendWire(conn, wire);
    }
  }

  void _send(_Conn conn, PartyMessage message) =>
      _sendWire(conn, PartyProtocol.encode(message));

  void _sendWire(_Conn conn, String wire) {
    try {
      conn.transport.send(wire);
    } catch (_) {
      // Remote already gone; prune below.
    }
  }
}