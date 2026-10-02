// End-to-end proof that the production pieces actually talk to each other
// over a real socket: SocketPartyTransport <-> PartyHostReference, the same
// authority every other multiplayer suite only ever drives over
// InMemoryPartyTransport ([[Multiplayer Development]]). This is the closest
// thing to `tool/dev_multiplayer_host.dart` that runs under `flutter test`.
import 'dart:io';

import 'package:are_you_stupid/multiplayer/engine/party_session.dart';
import 'package:are_you_stupid/multiplayer/engine/party_state.dart';
import 'package:are_you_stupid/multiplayer/networking/party_transport.dart';
import 'package:are_you_stupid/multiplayer/networking/session_socket.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/party_host_reference.dart';

Future<PartySession> _connectAndJoin(
  int port, {
  required String name,
}) async {
  final transport = await SocketPartyTransport.connect(
    InternetAddress.loopbackIPv4.address,
    port,
  );
  final session = PartySession(
    transport: transport,
    appName: 'test',
    appVersion: '0',
  );
  session.connect();
  await session.events.firstWhere((e) => e is PartyHandshakeEvent).timeout(
        const Duration(seconds: 3),
      );
  session.joinRoom(playerName: name, emoji: '🟢');
  await session.events.firstWhere((e) => e is PartyJoinedEvent).timeout(
        const Duration(seconds: 3),
      );
  return session;
}

void main() {
  test(
    'two real socket clients join, ready up, play a round and reach GAME_END',
    () async {
      final clock = FakePartyClock(1000);
      final host = PartyHostReference(
        hostName: 'integration-test-host',
        roomCode: 'TEST',
        battleRounds: 1,
        clock: clock,
      );

      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((socket) => host.attachClient(SocketPartyTransport(socket)));
      addTearDown(server.close);

      final a = await _connectAndJoin(server.port, name: 'Massimo');
      final b = await _connectAndJoin(server.port, name: 'Sami');
      addTearDown(a.dispose);
      addTearDown(b.dispose);

      a.setReady(true);
      b.setReady(true);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(a.state.players.every((p) => p.ready), isTrue);

      host.startGame();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(a.state.phase, PartyPhase.ready);
      expect(b.state.phase, PartyPhase.ready);

      host.startRandomRound(level: 1);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(a.state.round, isNotNull);
      expect(b.state.round, isNotNull);
      expect(a.state.round!.challengeId, b.state.round!.challengeId);
      expect(a.state.round!.seed, b.state.round!.seed);

      // Nobody answers — completeRound() judges both as a timeout and, with
      // battleRounds: 1, the host declares GAME_END right away.
      host.completeRound();
      await a.events.firstWhere((e) => e is PartyGameEndEvent).timeout(
            const Duration(seconds: 3),
          );
      await b.events.firstWhere((e) => e is PartyGameEndEvent).timeout(
            const Duration(seconds: 3),
          );

      expect(a.state.phase, PartyPhase.gameEnded);
      expect(b.state.phase, PartyPhase.gameEnded);
      expect(a.state.gameEnd!.results, hasLength(2));
    },
  );
}
