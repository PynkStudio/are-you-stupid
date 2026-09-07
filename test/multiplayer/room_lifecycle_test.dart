import 'dart:convert';

import 'package:are_you_stupid/multiplayer/engine/party_state.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/sim.dart';

void main() {
  group('gatekeeper', () {
    test('HELLO with a mismatched protocolVersion is REJECTED', () {
      final h = PartyHarness();
      final c = h.addClient(name: 'Ana');

      // Raw wrong-version handshake, bypassing the session's fixed version.
      c.sendRaw(jsonEncode({
        'type': 'HELLO',
        'protocolVersion': 99,
        'appName': 'x',
        'appVersion': '1',
      }));

      expect(c.state.phase, PartyPhase.rejected);
      expect(c.state.rejected, isNotNull);
      expect(c.state.rejected!.reason, contains('99'));
    });

    test('malformed input gets ERROR BAD_MESSAGE on the client', () {
      final h = PartyHarness();
      final c = h.addClient(name: 'Ana');
      c.sendRaw('{{{ not json');
      expect(c.state.lastError?.code, 'BAD_MESSAGE');
    });

    test('unknown type is ignored (forward-tolerant), connection stays up', () {
      final h = PartyHarness();
      final c = h.addClient(name: 'Ana');
      expect(c.state.phase, PartyPhase.lobby);
      c.sendRaw(jsonEncode({'type': 'FUTURE', 'ts': 0}));
      // Still the lobby; no error surfaced.
      expect(c.state.phase, PartyPhase.lobby);
      expect(c.state.lastError, isNull);
    });
  });

  group('room lifecycle', () {
    test('join populates roster and assigns a self id', () {
      final h = PartyHarness();
      final a = h.addClient(name: 'Ana');
      a.join(name: 'Ana');
      expect(a.state.selfClientId, isNotEmpty);
      expect(a.state.roomId, 'ABC123');
      expect(a.state.players, hasLength(1));
      expect(a.state.players.single.playerName, 'Ana');
      expect(a.lastEvent<PartyJoinedEvent>(), isNotNull);
    });

    test('capacity is enforced with ROOM_FULL error', () {
      final h = PartyHarness(maxPlayers: 2);
      final a = h.addClient(name: 'Ana');
      final b = h.addClient(name: 'Bob');
      a.join(name: 'Ana');
      b.join(name: 'Bob');

      final c = h.addClient(name: 'Cara');
      c.join(name: 'Cara');
      expect(c.state.lastError?.code, 'ROOM_FULL');
      expect(c.state.players, isEmpty);
    });

    test('leaving removes the seat and updates remaining rosters', () {
      final h = PartyHarness();
      final a = h.addClient(name: 'Ana');
      final b = h.addClient(name: 'Bob');
      a.join(name: 'Ana');
      b.join(name: 'Bob');
      expect(a.state.players, hasLength(2));

      a.leave();
      // b's roster drops Ana.
      expect(b.state.players, hasLength(1));
      expect(b.state.players.single.playerName, 'Bob');
    });

    test('ready toggles propagate to the roster', () {
      final h = PartyHarness();
      final a = h.addClient(name: 'Ana');
      final b = h.addClient(name: 'Bob');
      a.join(name: 'Ana');
      b.join(name: 'Bob');

      a.ready();
      expect(
        b.state.players.firstWhere((p) => p.playerName == 'Ana').ready,
        isTrue,
      );
      b.ready();

      a.ready(); // playerId is bound; a second ready is still fine / idempotent.
      final roster = b.state.players.where((p) => p.ready);
      expect(roster.length, 2);
    });

    test('game cannot start with fewer than 2 ready players', () {
      final h = PartyHarness();
      final a = h.addClient(name: 'Ana');
      a.join(name: 'Ana');
      a.ready();
      expect(() => h.host.startGame(), throwsStateError);
    });
  });
}
