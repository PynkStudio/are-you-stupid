import 'package:are_you_stupid/multiplayer/engine/party_state.dart';
import 'package:are_you_stupid/multiplayer/protocol/protocol.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/sim.dart';

void main() {
  group('multiplayer simulation (2-8 players)', () {
    test('eight players all join, ready, and see each other', () {
      final h = PartyHarness(maxPlayers: 8);
      final clients = <SimClient>[];
      for (var i = 1; i <= 8; i++) {
        final c = h.addClient(name: 'P$i', emoji: '🟢');
        c.join(name: 'P$i');
        c.ready();
        clients.add(c);
      }
      for (final c in clients) {
        expect(c.state.players, hasLength(8));
        expect(c.state.selfClientId, isNotEmpty);
      }
    });

    test('a full 4-player LSS game runs to a sole survivor', () {
      final h = PartyHarness(maxPlayers: 4, lives: 2);
      final clients = <SimClient>[];
      for (var i = 1; i <= 4; i++) {
        final c = h.addClient(name: 'P$i');
        c.join(name: 'P$i');
        c.ready();
        clients.add(c);
      }
      h.host.startGame(mode: GameMode.lastStupidStanding);

      // Drive rounds where each player except P1 taps (fails) twice, so they
      // are eliminated; P1 survives => P1 wins.
      var round = 0;
      while (h.host.inGame && round++ < 20) {
        h.host.startRound(challengeId: 'dont_tap', seed: 100 + round, level: 2);
        final alive = clients.where(
          (c) => !(c.state.standings[c.state.selfClientId]?.eliminated ?? false),
        );
        for (final c in alive) {
          // dont_tap: doing nothing is correct. P1 self-reports that via its
          // own runner timing out locally, exactly like a real silent-but-
          // connected phone would; everyone else taps (wrong) to get
          // eliminated on schedule.
          if (c == clients.first) {
            c.letRoundTimeOut();
          } else {
            c.tapBackground();
          }
        }
        h.host.completeRound();
      }

      // Game ended; everyone is in gameEnded.
      for (final c in clients) {
        expect(c.state.phase, PartyPhase.gameEnded);
      }
      expect(h.host.inGame, isFalse);
      expect(clients.first.state.gameEnd!.winnerId, clients.first.state.selfClientId);
    });

    test('eliminated players keep their seat as spectators', () {
      final h = PartyHarness(lives: 1);
      final a = h.addClient(name: 'A');
      final b = h.addClient(name: 'B');
      a.join(name: 'A');
      b.join(name: 'B');
      a.ready();
      b.ready();
      h.host.startGame(mode: GameMode.lastStupidStanding);

      h.host.startRound(challengeId: 'dont_tap', seed: 8, level: 2);
      b.tapBackground(); // wrong: dont_tap
      a.letRoundTimeOut(); // correct: dont_tap rewards doing nothing

      // b is eliminated (spectator) but still a seat; winner is a.
      expect(b.state.phase, PartyPhase.gameEnded);
      expect(b.state.gameEnd!.winnerId, a.state.selfClientId);
    });
  });
}
