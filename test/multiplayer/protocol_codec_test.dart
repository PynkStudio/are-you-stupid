import 'dart:convert';

import 'package:are_you_stupid/multiplayer/protocol/protocol.dart';
import 'package:flutter_test/flutter_test.dart';

const _ts = 1234;

Message _roundTrip<Message extends PartyMessage>(Message message) {
  final decoded = PartyProtocol.decode(PartyProtocol.encode(message));
  return (decoded as DecodedOk).message as Message;
}

void main() {
  group('PartyProtocol codec', () {
    test('every message round-trips without losing fields', () {
      expect(_roundTrip(const Hello(appName: 'ays', appVersion: '1.2.3')), isA<Hello>());

      final hostHello = _roundTrip(HostHello(
        hostName: 'h',
        roomCode: 'RC',
        maxPlayers: 4,
        protocolFeatures: const ['feature_a', 'feature_b'],
        ts: _ts,
      ));
      expect(hostHello.hostName, 'h');
      expect(hostHello.maxPlayers, 4);
      expect(hostHello.protocolFeatures, ['feature_a', 'feature_b']);

      final rejected = _roundTrip(Rejected(reason: 'version', ts: _ts));
      expect(rejected.reason, 'version');

      final join = _roundTrip(const JoinRoom(playerName: 'Ana', emoji: '😀'));
      expect(join.playerName, 'Ana');
      expect(join.emoji, '😀');

      final joined = _roundTrip(PlayerJoined(
        selfClientId: 'p1',
        roomId: 'RC',
        players: const [
          PlayerInfo(playerId: 'p1', playerName: 'Ana', emoji: '😀', ready: false),
        ],
      ));
      expect(joined.players, hasLength(1));

      final ready = _roundTrip(PlayerReady(playerId: 'p1', ready: true));
      expect(ready.playerId, 'p1');
      expect(ready.ready, isTrue);

      final roster = _roundTrip(PlayerReadyRoster(
        players: const [
          PlayerInfo(playerId: 'p1', playerName: 'Ana', emoji: '😀', ready: true),
        ],
      ));
      expect(roster.players.single.ready, isTrue);

      final start = _roundTrip(StartGame(
        mode: GameMode.lastStupidStanding,
        config: const {'lives': 3},
        ts: _ts,
      ));
      expect(start.mode, GameMode.lastStupidStanding);
      expect(start.config, {'lives': 3});

      final roundStart = _roundTrip(RoundStart(
        roundId: 'r1',
        challengeId: 'dont_tap',
        seed: 42,
        startAt: _ts,
        durationMs: 2000,
        config: const {'level': 3},
      ));
      expect(roundStart.challengeId, 'dont_tap');
      expect(roundStart.seed, 42);
      expect(roundStart.durationMs, 2000);

      final cd = _roundTrip(RoundCountdown(roundId: 'r1', atMs: 500, state: 'GO'));
      expect(cd.state, 'GO');

      final action = _roundTrip(PlayerAction(
        playerId: 'p1',
        roundId: 'r1',
        action: const PartyAction.count(4),
        clientTimestampMs: 7,
      ));
      final counted = action.action;
      expect(counted.kind, 'count');
      expect(counted.count, 4);

      final result = _roundTrip(RoundResult(
        roundId: 'r1',
        correct: true,
        reason: 'ok',
        scoreDelta: 100,
        actionReceivedMs: 999,
      ));
      expect(result.correct, isTrue);
      expect(result.scoreDelta, 100);

      final results = _roundTrip(RoundResults(
        roundId: 'r1',
        results: const [
          PlayerRoundResult(
            playerId: 'p1',
            correct: true,
            reason: 'ok',
            scoreDelta: 100,
            reactionMs: 500,
          ),
        ],
      ));
      expect(results.results.single.reactionMs, 500);

      final end = _roundTrip(GameEnd(
        mode: GameMode.stupidBattle,
        results: const [
          GameResultEntry(playerId: 'p1', score: 300, lives: null, standing: 1),
        ],
        winnerId: 'p1',
      ));
      expect(end.winnerId, 'p1');

      final error = _roundTrip(const PartyError(code: 'ROOM_FULL', detail: 'full'));
      expect(error.code, 'ROOM_FULL');
    });

    test('PartyAction.tap background (no target) round-trips', () {
      final decoded = PartyProtocol.decode(PartyProtocol.encode(
        PlayerAction(playerId: 'p1', roundId: 'r1', action: const PartyAction.tap()),
      )) as DecodedOk;
      final action = (decoded.message as PlayerAction).action;
      expect(action.kind, 'tap');
      expect(action.targetId, isNull);
      expect(action.index, isNull);
    });

    test('PartyAction.tap with target + index round-trips', () {
      final decoded = PartyProtocol.decode(PartyProtocol.encode(
        PlayerAction(
          playerId: 'p1',
          roundId: 'r1',
          action: const PartyAction.tap(targetId: 'bait', index: 1),
        ),
      )) as DecodedOk;
      final action = (decoded.message as PlayerAction).action;
      expect(action.targetId, 'bait');
      expect(action.index, 1);
    });

    test('unknown type decodes to DecodedUnknownType (forward-tolerant)', () {
      final decoded = PartyProtocol.decode(
        jsonEncode({'type': 'FUTURE_MESSAGE', 'ts': 0}),
      );
      expect(decoded, isA<DecodedUnknownType>());
    });

    test('missing type decodes to DecodedMalformed', () {
      expect(PartyProtocol.decode(jsonEncode({'ts': 0})), isA<DecodedMalformed>());
    });

    test('non-JSON decodes to DecodedMalformed', () {
      expect(PartyProtocol.decode('not json'), isA<DecodedMalformed>());
    });

    test('unknown fields on a known type are ignored (forward-tolerant)', () {
      final raw = jsonEncode({
        'type': 'PLAYER_READY',
        'playerId': 'p1',
        'ready': true,
        'futureField': {'anything': true},
        'ts': 5,
      });
      final decoded = PartyProtocol.decode(raw) as DecodedOk;
      final ready = decoded.message as PlayerReady;
      expect(ready.playerId, 'p1');
      expect(ready.ready, isTrue);
    });
  });
}
