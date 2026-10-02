/// Multiplayer wire protocol — pure Dart mirror of
/// `docs/Architecture/Multiplayer Protocol.md`.
///
/// This file is PURE DART on purpose: no Flutter imports. It models every
/// message from the protocol table and (de)serializes them as JSONL — one
/// JSON object per line, UTF-8. Both ends speak this exact contract: the
/// in-process host reference, the simulation harness, and eventually the
/// Swift host ([[Multiplayer Host (tvOS)]]) and the Flutter client
/// ([[Multiplayer Client (Mobile)]]).
///
/// Forward-tolerance rules (from the protocol note):
///  - unknown fields are ignored automatically (we only read known keys);
///  - an unknown `type` decodes to [DecodedUnknownType] so a caller can
///    ignore it and wait;
///  - anything that is not one JSON object decodes to [DecodedMalformed];
///  - `protocolVersion` is carried on the envelope; the host gatekeeper is
///    the only authority on it ([REJECTED] on mismatch).
library;

import 'dart:convert';

const int kProtocolVersion = 1;

/// The wire name of a game mode (`START_GAME.mode`, `GAME_END.mode`, ...).
enum GameMode {
  /// Last Stupid Standing: lives, eliminations, sole survivor wins.
  lastStupidStanding('lss'),

  /// Stupid Battle: fixed round count, points, best total wins.
  stupidBattle('battle');

  const GameMode(this.wire);
  final String wire;

  static GameMode fromWire(String? value) {
    for (final mode in GameMode.values) {
      if (mode.wire == value) return mode;
    }
    return GameMode.stupidBattle;
  }
}

/// Whether [`ROUND_END`] leaves the game in `GAME_END` state.
enum GameStatus { playing, ended }

/// Decode outcome.
sealed class DecodedMessage {}

/// A line that parsed into a known [[PartyMessage]].
final class DecodedOk extends DecodedMessage {
  DecodedOk(this.message);
  final PartyMessage message;
}

/// A well-formed JSON object whose `type` is not recognized. Forward-tolerant
/// callers ignore it and wait; the host may answer an `ERROR` if policy says so.
final class DecodedUnknownType extends DecodedMessage {
  DecodedUnknownType(this.rawType);
  final String rawType;
}

/// Anything that is not a single JSON object (empty, garbage, truncated
/// JSONL, oversized). Callers answer `BAD_MESSAGE`.
final class DecodedMalformed extends DecodedMessage {
  DecodedMalformed([this.reason = 'malformed frame']);
  final String reason;
}

/// A seat in the room (roster / ready snapshots).
class PlayerInfo {
  const PlayerInfo({
    required this.playerId,
    required this.playerName,
    this.emoji = '',
    this.ready = false,
  });

  final String playerId;
  final String playerName;
  final String emoji;
  final bool ready;

  Map<String, Object?> toWire() => {
        'playerId': playerId,
        'playerName': playerName,
        'emoji': emoji,
        'ready': ready,
      };

  static PlayerInfo fromWire(Map<String, Object?> w) => PlayerInfo(
        playerId: w['playerId'] as String? ?? '',
        playerName: w['playerName'] as String? ?? '',
        emoji: w['emoji'] as String? ?? '',
        ready: w['ready'] as bool? ?? false,
      );
}

/// One player's outcome inside `ROUND_RESULTS.results[]`.
class PlayerRoundResult {
  const PlayerRoundResult({
    required this.playerId,
    required this.correct,
    this.reason = '',
    this.scoreDelta = 0,
    this.reactionMs,
  });

  final String playerId;
  final bool correct;
  final String reason;
  final int scoreDelta;
  final int? reactionMs;

  Map<String, Object?> toWire() => {
        'playerId': playerId,
        'correct': correct,
        if (reason.isNotEmpty) 'reason': reason,
        'scoreDelta': scoreDelta,
        if (reactionMs != null) 'reactionMs': reactionMs,
      };

  static PlayerRoundResult fromWire(Map<String, Object?> w) => PlayerRoundResult(
        playerId: w['playerId'] as String? ?? '',
        correct: w['correct'] as bool? ?? false,
        reason: w['reason'] as String? ?? '',
        scoreDelta: w['scoreDelta'] as int? ?? 0,
        reactionMs: w['reactionMs'] as int?,
      );
}

/// One player's final placing inside `GAME_END.results[]`.
class GameResultEntry {
  const GameResultEntry({
    required this.playerId,
    this.score = 0,
    this.lives,
    required this.standing,
  });

  final String playerId;
  final int score;
  final int? lives;
  final int standing;

  Map<String, Object?> toWire() => {
        'playerId': playerId,
        'score': score,
        if (lives != null) 'lives': lives,
        'standing': standing,
      };

  static GameResultEntry fromWire(Map<String, Object?> w) => GameResultEntry(
        playerId: w['playerId'] as String? ?? '',
        score: w['score'] as int? ?? 0,
        lives: w['lives'] as int?,
        standing: w['standing'] as int? ?? 0,
      );
}

/// The input a client submits in a `PLAYER_ACTION`.
///
/// **Design change, see [[Decision Log]]:** the host used to rebuild the
/// canonical challenge and judge input itself. It no longer does — judging
/// 39 templates' often time-dependent logic (moving buttons, color shifts,
/// memory recall) a second time in Swift would mean keeping two
/// implementations of the same rules in permanent lockstep, which is exactly
/// the class of bug this project keeps tripping over. Instead, the *client*
/// judges — using the exact same `Challenge` engine every template already
/// has for single-player, via `PartyChallengeRunner` — and reports its
/// verdict (`PlayerAction.correct`/`reason`/`note`) alongside the raw input.
/// The host still owns *when* a round closes and still applies its own
/// duplicate/stale/late-action checks; it just no longer re-derives
/// *correctness*. This is a deliberate trust call for a local, in-person
/// party game: a modified client could self-report "always correct," which
/// is out of scope to defend against here. `elapsed` is still derived by
/// the host from its own clock for the round-expiry check, not trusted from
/// the client either.
///
/// [kind] is `tap` (a single pointer-down on a target or the background) or
/// `count` (the committed tap count for counting families like `tap_twice` /
/// `tap_exactly_n`, whose settle is judged by the host against the count).
/// The protocol's "one `PLAYER_ACTION` per player per round" rule (a duplicate
/// is answered `DUPLICATE_ACTION`) is why counting is committed as a count,
/// not replayed as repeated taps.
class PartyAction {
  const PartyAction.tap({
    this.targetId,
    this.index,
    this.kind = 'tap',
  }) : count = null;

  const PartyAction.count(this.count)
      : targetId = null,
        index = null,
        kind = 'count';

  final String kind;

  /// The tapped target's id, or null for a background tap (`kind: 'tap'`).
  final String? targetId;

  /// Visual index of the tapped target (0 = leftmost/first), if any.
  final int? index;

  /// Committed tap count (`kind: 'count'`) for counting challenges.
  final int? count;

  Map<String, Object?> toWire() {
    if (kind == 'count') {
      return {'kind': kind, 'count': count ?? 0};
    }
    return {
      'kind': kind,
      if (targetId != null) 'targetId': targetId,
      if (index != null) 'index': index,
    };
  }

  static PartyAction fromWire(Map<String, Object?> w) {
    final kind = w['kind'] as String? ?? 'tap';
    if (kind == 'count') {
      return PartyAction.count(w['count'] as int? ?? 0);
    }
    return PartyAction.tap(
      targetId: w['targetId'] as String?,
      index: w['index'] as int?,
    );
  }
}

/// Base class of every wire message. Each subtype knows its `type` string
/// and how to render its full JSON object (envelope included).
abstract class PartyMessage {
  const PartyMessage(this.ts);

  /// Local monotonic ms where the message was sent.
  final int ts;

  String get type;

  /// Full JSON object, envelope included: `{ protocolVersion, type, ts, ... }`.
  Map<String, Object?> toWire() => {
        'protocolVersion': kProtocolVersion,
        'type': type,
        'ts': ts,
      };
}

// ----------------------------------------------------------------- Lifecycle

/// client → host. First message after TCP connect.
class Hello extends PartyMessage {
  const Hello({required this.appName, required this.appVersion, int ts = 0})
      : super(ts);

  final String appName;
  final String appVersion;

  @override
  String get type => 'HELLO';

  @override
  Map<String, Object?> toWire() => {
        ...super.toWire(),
        'appName': appName,
        'appVersion': appVersion,
      };

  static Hello fromWire(Map<String, Object?> w, {int ts = 0}) => Hello(
        appName: w['appName'] as String? ?? '',
        appVersion: w['appVersion'] as String? ?? '',
        ts: ts,
      );
}

/// host → client. Greets; on version mismatch send [Rejected] instead.
class HostHello extends PartyMessage {
  const HostHello({
    required this.hostName,
    required this.roomCode,
    required this.maxPlayers,
    this.protocolFeatures = const [],
    int ts = 0,
  }) : super(ts);

  final String hostName;
  final String roomCode;
  final int maxPlayers;
  final List<String> protocolFeatures;

  @override
  String get type => 'HOST_HELLO';

  @override
  Map<String, Object?> toWire() => {
        ...super.toWire(),
        'hostName': hostName,
        'roomCode': roomCode,
        'maxPlayers': maxPlayers,
        'protocolFeatures': protocolFeatures,
      };

  static HostHello fromWire(Map<String, Object?> w, {int ts = 0}) => HostHello(
        hostName: w['hostName'] as String? ?? '',
        roomCode: w['roomCode'] as String? ?? '',
        maxPlayers: w['maxPlayers'] as int? ?? 8,
protocolFeatures: [
      for (final f in (w['protocolFeatures'] as List? ?? const []))
        if (f is String) f,
    ],
        ts: ts,
      );
}

/// either → either. Version or policy mismatch; connection should close.
class Rejected extends PartyMessage {
  const Rejected({this.reason = '', int ts = 0}) : super(ts);

  final String reason;

  @override
  String get type => 'REJECTED';

  @override
  Map<String, Object?> toWire() => {
        ...super.toWire(),
        'reason': reason,
      };

  static Rejected fromWire(Map<String, Object?> w, {int ts = 0}) => Rejected(
        reason: w['reason'] as String? ?? '',
        ts: ts,
      );
}

/// client → host. Request to join; host replies [PlayerJoined] or [PartyError].
class JoinRoom extends PartyMessage {
  const JoinRoom({required this.playerName, this.emoji = '', int ts = 0})
      : super(ts);

  final String playerName;
  final String emoji;

  @override
  String get type => 'JOIN_ROOM';

  @override
  Map<String, Object?> toWire() => {
        ...super.toWire(),
        'playerName': playerName,
        'emoji': emoji,
      };

  static JoinRoom fromWire(Map<String, Object?> w, {int ts = 0}) => JoinRoom(
        playerName: w['playerName'] as String? ?? '',
        emoji: w['emoji'] as String? ?? '',
        ts: ts,
      );
}

/// host → client. Full current player list snapshot, incl. self.
class PlayerJoined extends PartyMessage {
  const PlayerJoined({
    required this.selfClientId,
    required this.roomId,
    required this.players,
    int ts = 0,
  }) : super(ts);

  final String selfClientId;
  final String roomId;
  final List<PlayerInfo> players;

  @override
  String get type => 'PLAYER_JOINED';

  @override
  Map<String, Object?> toWire() => {
        ...super.toWire(),
        'selfClientId': selfClientId,
        'roomId': roomId,
        'players': [for (final p in players) p.toWire()],
      };

  static PlayerJoined fromWire(Map<String, Object?> w, {int ts = 0}) =>
      PlayerJoined(
        selfClientId: w['selfClientId'] as String? ?? '',
        roomId: w['roomId'] as String? ?? '',
        players: [
          for (final p in w['players'] as List? ?? const [])
            if (p is Map<String, Object?>) PlayerInfo.fromWire(p),
        ],
        ts: ts,
      );
}

/// client → host. Explicit leave; host then broadcasts [PlayerLeave].
class LeaveRoom extends PartyMessage {
  const LeaveRoom({int ts = 0}) : super(ts);

  @override
  String get type => 'LEAVE_ROOM';

  static LeaveRoom fromWire(Map<String, Object?> w, {int ts = 0}) =>
      LeaveRoom(ts: ts);
}

/// host → clients. Removes a seat from the lobby/roster.
class PlayerLeave extends PartyMessage {
  const PlayerLeave({
    required this.playerId,
    this.reason = 'left',
    int ts = 0,
  }) : super(ts);

  final String playerId;

  /// `left` or `disconnected`.
  final String reason;

  @override
  String get type => 'PLAYER_LEAVE';

  @override
  Map<String, Object?> toWire() => {
        ...super.toWire(),
        'playerId': playerId,
        'reason': reason,
      };

  static PlayerLeave fromWire(Map<String, Object?> w, {int ts = 0}) =>
      PlayerLeave(
        playerId: w['playerId'] as String? ?? '',
        reason: w['reason'] as String? ?? 'left',
        ts: ts,
      );
}

/// client ↔ host. Toggle ready state.
class PlayerReady extends PartyMessage {
  const PlayerReady({
    required this.playerId,
    required this.ready,
    int ts = 0,
  }) : super(ts);

  final String playerId;
  final bool ready;

  @override
  String get type => 'PLAYER_READY';

  @override
  Map<String, Object?> toWire() => {
        ...super.toWire(),
        'playerId': playerId,
        'ready': ready,
      };

  static PlayerReady fromWire(Map<String, Object?> w, {int ts = 0}) =>
      PlayerReady(
        playerId: w['playerId'] as String? ?? '',
        ready: w['ready'] as bool? ?? false,
        ts: ts,
      );
}

/// host → clients. Ready-state broadcast (lobby refresh).
class PlayerReadyRoster extends PartyMessage {
  const PlayerReadyRoster({required this.players, int ts = 0}) : super(ts);

  final List<PlayerInfo> players;

  @override
  String get type => 'PLAYER_READY_ROSTER';

  @override
  Map<String, Object?> toWire() => {
        ...super.toWire(),
        'players': [for (final p in players) p.toWire()],
      };

  static PlayerReadyRoster fromWire(Map<String, Object?> w, {int ts = 0}) =>
      PlayerReadyRoster(
        players: [
          for (final p in w['players'] as List? ?? const [])
            if (p is Map<String, Object?>) PlayerInfo.fromWire(p),
        ],
        ts: ts,
      );
}

/// host → clients. Only sent when ≥2 ready.
class StartGame extends PartyMessage {
  const StartGame({
    required this.mode,
    this.config = const {},
    int ts = 0,
  }) : super(ts);

  final GameMode mode;
  final Map<String, Object?> config;

  @override
  String get type => 'START_GAME';

  @override
  Map<String, Object?> toWire() => {
        ...super.toWire(),
        'mode': mode.wire,
        'config': config,
      };

  static StartGame fromWire(Map<String, Object?> w, {int ts = 0}) => StartGame(
        mode: GameMode.fromWire(w['mode'] as String?),
        config: (w['config'] as Map?)?.cast<String, Object?>() ?? const {},
        ts: ts,
      );
}

/// host → clients. In-match disconnect; grace window applies.
class PlayerDisconnected extends PartyMessage {
  const PlayerDisconnected({required this.playerId, int ts = 0}) : super(ts);

  final String playerId;

  @override
  String get type => 'PLAYER_DISCONNECTED';

  @override
  Map<String, Object?> toWire() => {
        ...super.toWire(),
        'playerId': playerId,
      };

  static PlayerDisconnected fromWire(Map<String, Object?> w, {int ts = 0}) =>
      PlayerDisconnected(
        playerId: w['playerId'] as String? ?? '',
        ts: ts,
      );
}

/// host → clients. Grace-window reconnect restored state.
class PlayerReconnected extends PartyMessage {
  const PlayerReconnected({required this.playerId, int ts = 0}) : super(ts);

  final String playerId;

  @override
  String get type => 'PLAYER_RECONNECTED';

  @override
  Map<String, Object?> toWire() => {
        ...super.toWire(),
        'playerId': playerId,
      };

  static PlayerReconnected fromWire(Map<String, Object?> w, {int ts = 0}) =>
      PlayerReconnected(
        playerId: w['playerId'] as String? ?? '',
        ts: ts,
      );
}

/// host → clients. Final; clients render result + share.
class GameEnd extends PartyMessage {
  const GameEnd({
    required this.mode,
    required this.results,
    this.winnerId,
    int ts = 0,
  }) : super(ts);

  final GameMode mode;
  final List<GameResultEntry> results;
  final String? winnerId;

  @override
  String get type => 'GAME_END';

  @override
  Map<String, Object?> toWire() => {
        ...super.toWire(),
        'mode': mode.wire,
        'results': [for (final r in results) r.toWire()],
        if (winnerId != null) 'winnerId': winnerId,
      };

  static GameEnd fromWire(Map<String, Object?> w, {int ts = 0}) => GameEnd(
        mode: GameMode.fromWire(w['mode'] as String?),
        results: [
          for (final r in w['results'] as List? ?? const [])
            if (r is Map<String, Object?>) GameResultEntry.fromWire(r),
        ],
        winnerId: w['winnerId'] as String?,
        ts: ts,
      );
}

// ------------------------------------------------------------------ Rounds

/// host → clients. The SAME challenge for every player, from one seed.
class RoundStart extends PartyMessage {
  const RoundStart({
    required this.roundId,
    required this.challengeId,
    required this.seed,
    required this.startAt,
    required this.durationMs,
    this.config = const {},
    int ts = 0,
  }) : super(ts);

  final String roundId;
  final String challengeId;
  final int seed;

  /// Shared epoch chosen by the host; clients count down from it.
  final int startAt;

  final int durationMs;

  /// Round-scoped config, e.g. `{ "level": 12 }`. Must stay small.
  final Map<String, Object?> config;

  @override
  String get type => 'ROUND_START';

  @override
  Map<String, Object?> toWire() => {
        ...super.toWire(),
        'roundId': roundId,
        'challengeId': challengeId,
        'seed': seed,
        'startAt': startAt,
        'durationMs': durationMs,
        'config': config,
      };

  static RoundStart fromWire(Map<String, Object?> w, {int ts = 0}) =>
      RoundStart(
        roundId: w['roundId'] as String? ?? '',
        challengeId: w['challengeId'] as String? ?? '',
        seed: w['seed'] as int? ?? 0,
        startAt: w['startAt'] as int? ?? 0,
        durationMs: w['durationMs'] as int? ?? 0,
        config: (w['config'] as Map?)?.cast<String, Object?>() ?? const {},
        ts: ts,
      );
}

/// host → clients. Countdown sync (`READY` / `GO`); `atMs` = host monotonic.
class RoundCountdown extends PartyMessage {
  const RoundCountdown({
    required this.roundId,
    required this.atMs,
    required this.state,
    int ts = 0,
  }) : super(ts);

  final String roundId;
  final int atMs;
  final String state;

  @override
  String get type => 'ROUND_COUNTDOWN';

  @override
  Map<String, Object?> toWire() => {
        ...super.toWire(),
        'roundId': roundId,
        'atMs': atMs,
        'state': state,
      };

  static RoundCountdown fromWire(Map<String, Object?> w, {int ts = 0}) =>
      RoundCountdown(
        roundId: w['roundId'] as String? ?? '',
        atMs: w['atMs'] as int? ?? 0,
        state: w['state'] as String? ?? 'READY',
        ts: ts,
      );
}

/// client → host. Carries the raw input *and* the client's own verdict —
/// see the design-change note on [PartyAction] above for why the host
/// trusts [correct]/[reason]/[note] instead of re-judging.
class PlayerAction extends PartyMessage {
  const PlayerAction({
    required this.playerId,
    required this.roundId,
    required this.action,
    required this.correct,
    this.reason,
    this.note,
    this.clientTimestampMs = 0,
    int ts = 0,
  }) : super(ts);

  final String playerId;
  final String roundId;
  final PartyAction action;

  /// The client's own verdict, computed by replaying the same `Challenge`
  /// single-player uses (`PartyChallengeRunner`). Authoritative — the host
  /// no longer rebuilds the challenge to check this.
  final bool correct;

  /// One-line wrong-answer explanation, shown on the board/other phones.
  /// Every template ships one per docs/Gameplay/Game Design Pillars.md.
  final String? reason;

  /// Optional correct-answer flourish (e.g. a reaction-time note).
  final String? note;

  /// Used only for the reaction-time bonus/tie-break, cross-checked by the
  /// host against its own `actionReceivedMs`. Never authoritative.
  final int clientTimestampMs;

  @override
  String get type => 'PLAYER_ACTION';

  @override
  Map<String, Object?> toWire() => {
        ...super.toWire(),
        'playerId': playerId,
        'roundId': roundId,
        'action': action.toWire(),
        'correct': correct,
        if (reason != null) 'reason': reason,
        if (note != null) 'note': note,
        'clientTimestampMs': clientTimestampMs,
      };

  static PlayerAction fromWire(Map<String, Object?> w, {int ts = 0}) =>
      PlayerAction(
        playerId: w['playerId'] as String? ?? '',
        roundId: w['roundId'] as String? ?? '',
        action: PartyAction.fromWire(
            (w['action'] as Map?)?.cast<String, Object?>() ?? const {}),
        correct: w['correct'] as bool? ?? false,
        reason: w['reason'] as String?,
        note: w['note'] as String?,
        clientTimestampMs: w['clientTimestampMs'] as int? ?? 0,
        ts: ts,
      );
}

/// host → each client. Per-player private result; also drives lives.
class RoundResult extends PartyMessage {
  const RoundResult({
    required this.roundId,
    required this.correct,
    this.reason = '',
    this.scoreDelta = 0,
    this.actionReceivedMs,
    int ts = 0,
  }) : super(ts);

  final String roundId;
  final bool correct;
  final String reason;
  final int scoreDelta;
  final int? actionReceivedMs;

  @override
  String get type => 'ROUND_RESULT';

  @override
  Map<String, Object?> toWire() => {
        ...super.toWire(),
        'roundId': roundId,
        'correct': correct,
        if (reason.isNotEmpty) 'reason': reason,
        'scoreDelta': scoreDelta,
        if (actionReceivedMs != null) 'actionReceivedMs': actionReceivedMs,
      };

  static RoundResult fromWire(Map<String, Object?> w, {int ts = 0}) =>
      RoundResult(
        roundId: w['roundId'] as String? ?? '',
        correct: w['correct'] as bool? ?? false,
        reason: w['reason'] as String? ?? '',
        scoreDelta: w['scoreDelta'] as int? ?? 0,
        actionReceivedMs: w['actionReceivedMs'] as int?,
        ts: ts,
      );
}

/// host → clients. Aggregated reveal for the TV + cross-phone standings.
class RoundResults extends PartyMessage {
  const RoundResults({
    required this.roundId,
    required this.results,
    int ts = 0,
  }) : super(ts);

  final String roundId;
  final List<PlayerRoundResult> results;

  @override
  String get type => 'ROUND_RESULTS';

  @override
  Map<String, Object?> toWire() => {
        ...super.toWire(),
        'roundId': roundId,
        'results': [for (final r in results) r.toWire()],
      };

  static RoundResults fromWire(Map<String, Object?> w, {int ts = 0}) =>
      RoundResults(
        roundId: w['roundId'] as String? ?? '',
        results: [
          for (final r in w['results'] as List? ?? const [])
            if (r is Map<String, Object?>) PlayerRoundResult.fromWire(r),
        ],
        ts: ts,
      );
}

/// host → clients. Bookend; clients lock accuracy/points, TV shows NEXT ROUND.
class RoundEnd extends PartyMessage {
  const RoundEnd({required this.roundId, int ts = 0}) : super(ts);

  final String roundId;

  @override
  String get type => 'ROUND_END';

  @override
  Map<String, Object?> toWire() => {
        ...super.toWire(),
        'roundId': roundId,
      };

  static RoundEnd fromWire(Map<String, Object?> w, {int ts = 0}) => RoundEnd(
        roundId: w['roundId'] as String? ?? '',
        ts: ts,
      );
}

/// host → clients. Broadcast on reaching 0 lives.
class PlayerEliminated extends PartyMessage {
  const PlayerEliminated({
    required this.roundId,
    required this.playerId,
    this.livesLeft = 0,
    int ts = 0,
  }) : super(ts);

  final String roundId;
  final String playerId;
  final int livesLeft;

  @override
  String get type => 'PLAYER_ELIMINATED';

  @override
  Map<String, Object?> toWire() => {
        ...super.toWire(),
        'roundId': roundId,
        'playerId': playerId,
        'livesLeft': livesLeft,
      };

  static PlayerEliminated fromWire(Map<String, Object?> w, {int ts = 0}) =>
      PlayerEliminated(
        roundId: w['roundId'] as String? ?? '',
        playerId: w['playerId'] as String? ?? '',
        livesLeft: w['livesLeft'] as int? ?? 0,
        ts: ts,
      );
}

/// host → clients. Live scoreboard patch.
class PlayerScore extends PartyMessage {
  const PlayerScore({
    required this.playerId,
    required this.mode,
    required this.score,
    this.lives,
    this.standing = 0,
    int ts = 0,
  }) : super(ts);

  final String playerId;
  final GameMode mode;
  final int score;

  /// Lives remaining (elimination modes). Null in pure point modes.
  final int? lives;
  final int standing;

  @override
  String get type => 'PLAYER_SCORE';

  @override
  Map<String, Object?> toWire() => {
        ...super.toWire(),
        'playerId': playerId,
        'mode': mode.wire,
        'score': score,
        if (lives != null) 'lives': lives,
        'standing': standing,
      };

  static PlayerScore fromWire(Map<String, Object?> w, {int ts = 0}) =>
      PlayerScore(
        playerId: w['playerId'] as String? ?? '',
        mode: GameMode.fromWire(w['mode'] as String?),
        score: w['score'] as int? ?? 0,
        lives: w['lives'] as int?,
        standing: w['standing'] as int? ?? 0,
        ts: ts,
      );
}

// ------------------------------------------------------------------- Errors

/// either → either. `code` is one of `ROOM_FULL`, `ROUND_CLOSED`,
/// `DUPLICATE_ACTION`, `BAD_MESSAGE`, ...; `detail` is the readable why.
class PartyError extends PartyMessage {
  const PartyError({required this.code, this.detail = '', int ts = 0})
      : super(ts);

  final String code;
  final String detail;

  @override
  String get type => 'ERROR';

  @override
  Map<String, Object?> toWire() => {
        ...super.toWire(),
        'code': code,
        'detail': detail,
      };

  static PartyError fromWire(Map<String, Object?> w, {int ts = 0}) =>
      PartyError(
        code: w['code'] as String? ?? '',
        detail: w['detail'] as String? ?? '',
        ts: ts,
      );
}

// ------------------------------------------------------- AI Director (Phase 7)
//
// Additive kinds for [[Multiplayer AI Director]]. Naming follows this
// protocol's own convention (flat Upper-`SNAKE_CASE`, no direction prefix)
// rather than the design doc's `client/aiCapabilities`-style sketch — see
// the 2026-09-11 Phase 7 [[Decision Log]] entry. `proposal` stays an opaque
// `Map<String, Object?>` here (this file has no `lib/ai/` dependency by
// design, same as `RoundStart.config`); callers decode it via
// `ChallengeProposal.fromJson`.

/// client → host, once after connecting: whether this phone can run the
/// on-device model, for the host's Director election.
class AiCapabilities extends PartyMessage {
  const AiCapabilities({
    required this.aiAvailable,
    this.computeRank = 0,
    this.batteryPercent = 100,
    int ts = 0,
  }) : super(ts);

  final bool aiAvailable;

  /// Tie-break rank. v1 keeps this a single tier (`aiAvailable ? 1 : 0`) —
  /// see the Phase 8 [[Decision Log]] entry on why a finer SoC-based rank
  /// isn't worth a new dependency.
  final int computeRank;
  final int batteryPercent;

  @override
  String get type => 'AI_CAPABILITIES';

  @override
  Map<String, Object?> toWire() => {
        ...super.toWire(),
        'aiAvailable': aiAvailable,
        'computeRank': computeRank,
        'batteryPercent': batteryPercent,
      };

  static AiCapabilities fromWire(Map<String, Object?> w, {int ts = 0}) =>
      AiCapabilities(
        aiAvailable: w['aiAvailable'] as bool? ?? false,
        computeRank: w['computeRank'] as int? ?? 0,
        batteryPercent: w['batteryPercent'] as int? ?? 100,
        ts: ts,
      );
}

/// host → all: who won the Director election, or `null` when no capable
/// phone is connected (the match plays 100% scripted).
class AiDirectorAssignment extends PartyMessage {
  const AiDirectorAssignment({this.directorPeerId, int ts = 0}) : super(ts);

  final String? directorPeerId;

  @override
  String get type => 'AI_DIRECTOR_ASSIGNMENT';

  @override
  Map<String, Object?> toWire() => {
        ...super.toWire(),
        if (directorPeerId != null) 'directorPeerId': directorPeerId,
      };

  static AiDirectorAssignment fromWire(Map<String, Object?> w, {int ts = 0}) =>
      AiDirectorAssignment(
        directorPeerId: w['directorPeerId'] as String?,
        ts: ts,
      );
}

/// client → host, Director only: a validated `ChallengeProposal` the host
/// should relay as this round's content instead of a scripted
/// `{challengeId, seed}` pick.
class AiRoundProposal extends PartyMessage {
  const AiRoundProposal({
    required this.roundId,
    required this.proposal,
    int ts = 0,
  }) : super(ts);

  final String roundId;
  final Map<String, Object?> proposal;

  @override
  String get type => 'AI_ROUND_PROPOSAL';

  @override
  Map<String, Object?> toWire() => {
        ...super.toWire(),
        'roundId': roundId,
        'proposal': proposal,
      };

  static AiRoundProposal fromWire(Map<String, Object?> w, {int ts = 0}) =>
      AiRoundProposal(
        roundId: w['roundId'] as String? ?? '',
        proposal: (w['proposal'] as Map?)?.cast<String, Object?>() ?? const {},
        ts: ts,
      );
}

/// host → all: the AI-authored round, relayed as-is from the Director's
/// `AiRoundProposal` (the host trusts it the same way it trusts every
/// player's self-reported `PlayerAction.correct` — see [[Decision Log]]).
/// Opens a round exactly like `ROUND_START`, but the full proposal travels
/// on the wire since there's no shared generator to replay from a seed.
class AiChallengeRound extends PartyMessage {
  const AiChallengeRound({
    required this.roundId,
    required this.proposal,
    required this.startAt,
    required this.durationMs,
    int ts = 0,
  }) : super(ts);

  final String roundId;
  final Map<String, Object?> proposal;
  final int startAt;
  final int durationMs;

  @override
  String get type => 'AI_CHALLENGE_ROUND';

  @override
  Map<String, Object?> toWire() => {
        ...super.toWire(),
        'roundId': roundId,
        'proposal': proposal,
        'startAt': startAt,
        'durationMs': durationMs,
      };

  static AiChallengeRound fromWire(Map<String, Object?> w, {int ts = 0}) =>
      AiChallengeRound(
        roundId: w['roundId'] as String? ?? '',
        proposal: (w['proposal'] as Map?)?.cast<String, Object?>() ?? const {},
        startAt: w['startAt'] as int? ?? 0,
        durationMs: w['durationMs'] as int? ?? 0,
        ts: ts,
      );
}

/// client → host, Director only: a validated commentary line for [kind]/
/// [roundId] ([[AI Commentary]]).
class AiCommentaryProposal extends PartyMessage {
  const AiCommentaryProposal({
    required this.kind,
    required this.roundId,
    required this.text,
    int ts = 0,
  }) : super(ts);

  final String kind;
  final String roundId;
  final String text;

  @override
  String get type => 'AI_COMMENTARY_PROPOSAL';

  @override
  Map<String, Object?> toWire() => {
        ...super.toWire(),
        'kind': kind,
        'roundId': roundId,
        'text': text,
      };

  static AiCommentaryProposal fromWire(Map<String, Object?> w, {int ts = 0}) =>
      AiCommentaryProposal(
        kind: w['kind'] as String? ?? '',
        roundId: w['roundId'] as String? ?? '',
        text: w['text'] as String? ?? '',
        ts: ts,
      );
}

/// host → all: the commentary line relayed from the Director, as-is.
class AiCommentary extends PartyMessage {
  const AiCommentary({
    required this.kind,
    required this.roundId,
    required this.text,
    int ts = 0,
  }) : super(ts);

  final String kind;
  final String roundId;
  final String text;

  @override
  String get type => 'AI_COMMENTARY';

  @override
  Map<String, Object?> toWire() => {
        ...super.toWire(),
        'kind': kind,
        'roundId': roundId,
        'text': text,
      };

  static AiCommentary fromWire(Map<String, Object?> w, {int ts = 0}) =>
      AiCommentary(
        kind: w['kind'] as String? ?? '',
        roundId: w['roundId'] as String? ?? '',
        text: w['text'] as String? ?? '',
        ts: ts,
      );
}

// ------------------------------------------------------------------- Codec

/// The JSONL codec shared by host, client, mirrors and tests.
abstract final class PartyProtocol {
  /// Fresh monotonic ms source (injectable for deterministic tests).
  static int now() => DateTime.now().millisecondsSinceEpoch;

  /// Serializes a message to one JSONL line (no trailing newline).
  static String encode(PartyMessage message) => jsonEncode(message.toWire());

  /// Parses one line. See the [DecodedMessage] trio for outcome semantics.
  static DecodedMessage decode(String line) {
    final Object? json;
    try {
      json = jsonDecode(line);
    } on FormatException {
      return DecodedMalformed('not JSON');
    }
    if (json is! Map) return DecodedMalformed('not an object');

    final wire = json.cast<String, Object?>();
    final type = wire['type'] as String?;
    if (type == null || type.isEmpty) return DecodedMalformed('missing type');
    final ts = wire['ts'] as int? ?? 0;

    switch (type) {
      case 'HELLO':
        return DecodedOk(Hello.fromWire(wire, ts: ts));
      case 'HOST_HELLO':
        return DecodedOk(HostHello.fromWire(wire, ts: ts));
      case 'REJECTED':
        return DecodedOk(Rejected.fromWire(wire, ts: ts));
      case 'JOIN_ROOM':
        return DecodedOk(JoinRoom.fromWire(wire, ts: ts));
      case 'PLAYER_JOINED':
        return DecodedOk(PlayerJoined.fromWire(wire, ts: ts));
      case 'LEAVE_ROOM':
        return DecodedOk(LeaveRoom.fromWire(wire, ts: ts));
      case 'PLAYER_LEAVE':
        return DecodedOk(PlayerLeave.fromWire(wire, ts: ts));
      case 'PLAYER_READY':
        return DecodedOk(PlayerReady.fromWire(wire, ts: ts));
      case 'PLAYER_READY_ROSTER':
        return DecodedOk(PlayerReadyRoster.fromWire(wire, ts: ts));
      case 'START_GAME':
        return DecodedOk(StartGame.fromWire(wire, ts: ts));
      case 'PLAYER_DISCONNECTED':
        return DecodedOk(PlayerDisconnected.fromWire(wire, ts: ts));
      case 'PLAYER_RECONNECTED':
        return DecodedOk(PlayerReconnected.fromWire(wire, ts: ts));
      case 'GAME_END':
        return DecodedOk(GameEnd.fromWire(wire, ts: ts));
      case 'ROUND_START':
        return DecodedOk(RoundStart.fromWire(wire, ts: ts));
      case 'ROUND_COUNTDOWN':
        return DecodedOk(RoundCountdown.fromWire(wire, ts: ts));
      case 'PLAYER_ACTION':
        return DecodedOk(PlayerAction.fromWire(wire, ts: ts));
      case 'ROUND_RESULT':
        return DecodedOk(RoundResult.fromWire(wire, ts: ts));
      case 'ROUND_RESULTS':
        return DecodedOk(RoundResults.fromWire(wire, ts: ts));
      case 'ROUND_END':
        return DecodedOk(RoundEnd.fromWire(wire, ts: ts));
      case 'PLAYER_ELIMINATED':
        return DecodedOk(PlayerEliminated.fromWire(wire, ts: ts));
      case 'PLAYER_SCORE':
        return DecodedOk(PlayerScore.fromWire(wire, ts: ts));
      case 'ERROR':
        return DecodedOk(PartyError.fromWire(wire, ts: ts));
      case 'AI_CAPABILITIES':
        return DecodedOk(AiCapabilities.fromWire(wire, ts: ts));
      case 'AI_DIRECTOR_ASSIGNMENT':
        return DecodedOk(AiDirectorAssignment.fromWire(wire, ts: ts));
      case 'AI_ROUND_PROPOSAL':
        return DecodedOk(AiRoundProposal.fromWire(wire, ts: ts));
      case 'AI_CHALLENGE_ROUND':
        return DecodedOk(AiChallengeRound.fromWire(wire, ts: ts));
      case 'AI_COMMENTARY_PROPOSAL':
        return DecodedOk(AiCommentaryProposal.fromWire(wire, ts: ts));
      case 'AI_COMMENTARY':
        return DecodedOk(AiCommentary.fromWire(wire, ts: ts));
      default:
        return DecodedUnknownType(type);
    }
  }

  /// Convenience: encodes then decodes (round-trip helper for tests).
  static PartyMessage roundTrip(PartyMessage message) {
    final decoded = decode(encode(message));
    return (decoded as DecodedOk).message;
  }
}