import 'package:are_you_stupid/multiplayer/engine/party_state.dart';
import 'package:are_you_stupid/multiplayer/protocol/protocol.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/sim.dart';

void main() {
  group('round sync', () {
    test('every client rebuilds the same canonical challenge from seed', () {
      final h = PartyHarness();
      final a = h.addClient(name: 'Ana');
      final b = h.addClient(name: 'Bob');
      a.join(name: 'Ana');
      b.join(name: 'Bob');
      a.ready();
      b.ready();
      h.host.startGame(mode: GameMode.stupidBattle);
      h.host.startRound(challengeId: 'dont_tap', seed: 4242, level: 2);

      final viewA = a.state.round!.view;
      final viewB = b.state.round!.view;
      expect(viewA.instruction, viewB.instruction);
      expect(a.state.currentChallengeId, 'dont_tap');
      expect(b.state.currentChallengeId, 'dont_tap');
      expect(a.state.phase, PartyPhase.round);
    });

    test('countdown frames set READY then GO on the client', () {
      final h = PartyHarness();
      final a = h.addClient(name: 'Ana');
      final b = h.addClient(name: 'Bob');
      a.join(name: 'Ana');
      b.join(name: 'Bob');
      a.ready();
      b.ready();
      h.host.startGame();
      h.host.startRound(challengeId: 'dont_tap', seed: 1, level: 2);

      // startRound emits READY then GO in one synchronous flush; last wins.
      expect(a.state.round!.isGo, isTrue);
      expect(a.state.round!.countdownState, 'GO');
    });
  });

  group('round auto-closes once every alive seat has answered (no downtime)', () {
    test('closes as soon as the last alive seat answers, no completeRound() call', () {
      final h = PartyHarness();
      final a = h.addClient(name: 'Ana');
      final b = h.addClient(name: 'Bob');
      final c = h.addClient(name: 'Cid');
      a.join(name: 'Ana');
      b.join(name: 'Bob');
      c.join(name: 'Cid');
      a.ready();
      b.ready();
      c.ready();
      h.host.startGame();
      h.host.startRound(challengeId: 'tap_exactly_n', seed: 7, level: 2);
      final n = a.correctTapCount()!;

      a.commitCount(n);
      expect(a.state.phase, PartyPhase.round, reason: 'still waiting on Bob and Cid');

      b.commitCount(n);
      expect(a.state.phase, PartyPhase.round, reason: 'still waiting on Cid');

      c.commitCount(n);
      // No explicit h.host.completeRound() anywhere above.
      expect(a.state.phase, PartyPhase.playing, reason: 'the last answer should have closed the round on its own');
    });

    test('ignores an eliminated seat — only alive seats are waited on', () {
      final h = PartyHarness(lives: 1);
      final a = h.addClient(name: 'Ana');
      final b = h.addClient(name: 'Bob');
      final c = h.addClient(name: 'Cid');
      a.join(name: 'Ana');
      b.join(name: 'Bob');
      c.join(name: 'Cid');
      a.ready();
      b.ready();
      c.ready();
      h.host.startGame(mode: GameMode.lastStupidStanding);

      // Eliminate Cid on round 1 with a deliberately wrong count (also
      // closes round 1 on its own once all three have answered).
      h.host.startRound(challengeId: 'tap_exactly_n', seed: 1, level: 2);
      final n1 = a.correctTapCount()!;
      a.commitCount(n1);
      b.commitCount(n1);
      c.commitCount(n1 + 3); // definitely wrong
      expect(c.state.standings[c.state.selfClientId]!.eliminated, isTrue);

      h.host.startRound(challengeId: 'tap_exactly_n', seed: 2, level: 2);
      final n2 = a.correctTapCount()!;
      a.commitCount(n2);
      expect(a.state.phase, PartyPhase.round, reason: 'still waiting on Bob; Cid is eliminated and never expected to answer');
      b.commitCount(n2);
      expect(a.state.phase, PartyPhase.playing, reason: 'Bob was the only other alive seat');
    });
  });

  group('counting (count action) judging', () {
    test('correct exact count passes; the host replies ROundResult correct', () {
      final h = PartyHarness();
      final a = h.addClient(name: 'Ana');
      final b = h.addClient(name: 'Bob');
      a.join(name: 'Ana');
      b.join(name: 'Bob');
      a.ready();
      b.ready();
      h.host.startGame();
      h.host.startRound(challengeId: 'tap_exactly_n', seed: 7, level: 2);

      // The client's rebuilt challenge reveals the canonical correct count.
      final n = a.correctTapCount();
      expect(n, isNotNull);
      a.commitCount(n!);

      h.host.completeRound();
      final result = a.state.privateResult!;
      expect(result.correct, isTrue);
    });

    test('wrong count fails the round', () {
      final h = PartyHarness();
      final a = h.addClient(name: 'Ana');
      final b = h.addClient(name: 'Bob');
      a.join(name: 'Ana');
      b.join(name: 'Bob');
      a.ready();
      b.ready();
      h.host.startGame();
      h.host.startRound(challengeId: 'tap_exactly_n', seed: 7, level: 2);

      final n = a.correctTapCount()!;
      a.commitCount(n + 3); // definitely too many
      h.host.completeRound();
      expect(a.state.privateResult!.correct, isFalse);
    });
  });

  group('Last Stupid Standing', () {
    test('a wrong answer costs a life; three wrongs eliminate the player', () {
      final h = PartyHarness(lives: 3);
      final a = h.addClient(name: 'Ana');
      final b = h.addClient(name: 'Bob');
      a.join(name: 'Ana');
      b.join(name: 'Bob');
      a.ready();
      b.ready();
      h.host.startGame(mode: GameMode.lastStupidStanding);

      // dont_tap: the only way to fail is to tap. Send a tap => wrong.
      for (var i = 0; i < 3; i++) {
        h.host.startRound(challengeId: 'dont_tap', seed: 1000 + i, level: 2);
        a.tapBackground();
        h.host.completeRound();
      }
      expect(a.state.standings[a.state.selfClientId]!.eliminated, isTrue);
      expect(a.lastEvent<PartyEliminatedEvent>(), isNotNull);
    });

    test('tapping is wrong and timing out on dont_tap is correct', () {
      final h = PartyHarness();
      final a = h.addClient(name: 'Ana');
      final b = h.addClient(name: 'Bob');
      a.join(name: 'Ana');
      b.join(name: 'Bob');
      a.ready();
      b.ready();
      h.host.startGame(mode: GameMode.lastStupidStanding);

      h.host.startRound(challengeId: 'dont_tap', seed: 55, level: 2);
      a.tapBackground(); // wrong: tapped the bait / background
      b.letRoundTimeOut(); // dont_tap: doing nothing is correct
      // a submitted wrong; b's own runner timed out locally and
      // self-reported correct — the round auto-closes once both have
      // answered, no explicit completeRound() needed.
      expect(a.state.privateResult!.correct, isFalse);
      expect(b.state.privateResult!.correct, isTrue);
    });

    test('sole survivor triggers GAME_END with a winner', () {
      final h = PartyHarness(lives: 1);
      final a = h.addClient(name: 'Ana');
      final b = h.addClient(name: 'Bob');
      a.join(name: 'Ana');
      b.join(name: 'Bob');
      a.ready();
      b.ready();
      h.host.startGame(mode: GameMode.lastStupidStanding);

      // Kill Bob on the first round; Ana survives => Bob eliminated, Ana wins.
      h.host.startRound(challengeId: 'dont_tap', seed: 3, level: 2);
      b.tapBackground(); // wrong: dont_tap
      a.letRoundTimeOut(); // correct: dont_tap rewards doing nothing

      expect(a.state.phase, PartyPhase.gameEnded);
      expect(a.state.gameEnd!.winnerId, a.state.selfClientId);
      expect(b.state.phase, PartyPhase.gameEnded);
    });
  });

  group('Battle scoring + reaction bonus', () {
    test('correct answers score points; fastest correct gets the bonus', () {
      final h = PartyHarness(battleRounds: 1, speedBonus: true);
      final a = h.addClient(name: 'Ana');
      final b = h.addClient(name: 'Bob');
      a.join(name: 'Ana');
      b.join(name: 'Bob');
      a.ready();
      b.ready();
      h.host.startGame(mode: GameMode.stupidBattle);

      h.host.startRound(challengeId: 'tap_exactly_n', seed: 21, level: 2);
      final n = a.correctTapCount()!;
      final m = b.correctTapCount()!;
      expect(n, m); // same canonical challenge => same answer.
      a.commitCount(n);
      b.commitCount(m);
      h.host.completeRound();

      final aScore = a.state.standings[a.state.selfClientId]!.score;
      expect(aScore, greaterThanOrEqualTo(100));
      // Each PlayerScore broadcast reflects the best score after the round.
      expect(a.state.phase, PartyPhase.gameEnded);
      expect(a.state.gameEnd!.results, isNotEmpty);
    });

    test('correct but slower player does not get the top bonus', () {
      // Both correct, but Ana reacts first, Bob later. Ana takes the +50 top
      // bonus (150), Bob only the +25 second-place bonus (125). If the
      // reaction ordering were ignored both would tie at 150.
      final h = PartyHarness(battleRounds: 1, speedBonus: true);
      final a = h.addClient(name: 'Ana');
      final b = h.addClient(name: 'Bob');
      a.join(name: 'Ana');
      b.join(name: 'Bob');
      a.ready();
      b.ready();
      h.host.startGame(mode: GameMode.stupidBattle);
      h.host.startRound(challengeId: 'tap_exactly_n', seed: 555, level: 2);

      final n = a.correctTapCount()!;
      expect(b.correctTapCount(), n);
      a.commitCount(n);
      h.host.clock.advance(250);
      b.commitCount(n);
      h.host.completeRound(); // both judged correct.

      final aScore = a.state.standings[a.state.selfClientId]!.score;
      final bScore = b.state.standings[b.state.selfClientId]!.score;
      expect(aScore, 150); // 100 base + 50 fastest bonus.
      expect(bScore, 125); // 100 base + 25 second bonus.
      expect(a.state.gameEnd!.results.first.playerId, a.state.selfClientId);
    });
  });
}
