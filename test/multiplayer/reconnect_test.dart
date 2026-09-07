import 'package:are_you_stupid/multiplayer/engine/party_state.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/sim.dart';

void main() {
  group('grace reconnect', () {
    test('in-game drop holds the seat and a matching reconnect restores it', () {
      final h = PartyHarness(graceWindowMs: 15000);
      final a = h.addClient(name: 'Ana');
      final b = h.addClient(name: 'Bob');
      a.join(name: 'Ana');
      b.join(name: 'Bob');
      a.ready();
      b.ready();
      h.host.startGame();

      // Simulate Ana's network vanishing (session transport drops).
      // Here we simply drop the client transport and check the host broadcasts
      // a disconnect while the seat is held.
      a.clientTransport.close();
      // a's session is now disconnected; b receives the disconnect event.
      expect(b.lastEvent<PartyPlayerDisconnectedEvent>(), isNotNull);

      // Bob reconnects as a brand new session identity Ana (name+emoji) after
      // the transport drop within the grace window — but the harness pairs a
      // fresh transport, so we instead drive the host directly: a *new* client
      // connection with the same name+emoji reconnects Ana's held seat.
      final a2 = h.addClient(name: 'Ana');
      a2.join(name: 'Ana'); // same playerName+emoji -> reconnect
      expect(a2.state.selfClientId, a.state.selfClientId);
      expect(b.lastEvent<PartyPlayerReconnectedEvent>(), isNotNull);
    });

    test('grace window expiry prunes the disconnected player', () {
      final h = PartyHarness(graceWindowMs: 5000);
      final a = h.addClient(name: 'Ana');
      final b = h.addClient(name: 'Bob');
      a.join(name: 'Ana');
      b.join(name: 'Bob');
      a.ready();
      b.ready();
      h.host.startGame();

      a.clientTransport.close();
      expect(b.lastEvent<PartyPlayerDisconnectedEvent>(), isNotNull);

      // Advance past the grace window and let the host prune at the next
      // round boundary.
      h.clock.advance(6000);
      h.host.startRound(challengeId: 'dont_tap', seed: 1, level: 2);

      expect(b.lastEvent<PartyPlayerLeftEvent>(), isNotNull);
      final leave = b.lastEvent<PartyPlayerLeftEvent>()!.leave;
      expect(leave.reason, 'disconnected');
    });

    test('reconnect outside the grace window is rejected', () {
      final h = PartyHarness(graceWindowMs: 1000);
      final a = h.addClient(name: 'Ana');
      final b = h.addClient(name: 'Bob');
      a.join(name: 'Ana');
      b.join(name: 'Bob');
      a.ready();
      b.ready();
      h.host.startGame();

      a.clientTransport.close();

      // Expire the window.
      h.clock.advance(2500);
      h.host.startRound(challengeId: 'dont_tap', seed: 2, level: 2);

      // Now a fresh Ana attempt cannot reconnect (seat already pruned).
      final a2 = h.addClient(name: 'Ana');
      a2.join(name: 'Ana');
      expect(a2.state.lastError, isNotNull);
    });
  });

  group('duplicate / stale action validation', () {
    test('a second action in the same round is DUPLICATE_ACTION', () {
      final h = PartyHarness();
      final a = h.addClient(name: 'Ana');
      final b = h.addClient(name: 'Bob');
      a.join(name: 'Ana');
      b.join(name: 'Bob');
      a.ready();
      b.ready();
      h.host.startGame();
      h.host.startRound(challengeId: 'dont_tap', seed: 5, level: 2);

      a.tapBackground();
      final first = a.state.privateResult!;
      expect(first.correct, isFalse);
      a.tapBackground(); // second submit -> duplicate
      expect(a.state.lastError?.code, 'DUPLICATE_ACTION');
    });

    test('action before a round is open is ROUND_CLOSED', () {
      final h = PartyHarness();
      final a = h.addClient(name: 'Ana');
      final b = h.addClient(name: 'Bob');
      a.join(name: 'Ana');
      b.join(name: 'Bob');
      a.ready();
      b.ready();
      h.host.startGame(); // no round open yet

      // The session refuses to send without a round; inject the action straight
      // into the host to exercise its ROUND_CLOSED guard.
      a.sendRaw(
        '{"type":"PLAYER_ACTION","playerId":"${a.state.selfClientId}",'
        '"roundId":"r1","action":{"kind":"tap"},"ts":0}',
      );
      expect(a.state.lastError?.code, 'ROUND_CLOSED');
    });
  });
}
