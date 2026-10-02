import 'dart:math';

import 'package:are_you_stupid/ai/providers.dart';
import 'package:are_you_stupid/challenges/registry.dart';
import 'package:are_you_stupid/core/challenge.dart';
import 'package:are_you_stupid/core/challenge_generator.dart';
import 'package:are_you_stupid/core/difficulty.dart';
import 'package:are_you_stupid/core/game_engine.dart';
import 'package:are_you_stupid/core/game_state.dart';
import 'package:flutter_test/flutter_test.dart';

class _StubChallenge extends Challenge {
  _StubChallenge(super.params);

  @override
  String get id => 'stub';

  @override
  ChallengeTag get tag => ChallengeTag.color;

  @override
  Duration get duration => const Duration(seconds: 2);

  @override
  ChallengeView get view => const ChallengeView(
        instruction: 'TAP GOOD',
        layout: ChallengeLayout.row,
        targets: [
          TargetSpec(id: 'good'),
          TargetSpec(id: 'bad'),
        ],
      );

  @override
  void onTap(TapInfo tap, ChallengeHost host) {
    if (tap.targetId == 'good') {
      host.pass();
    } else {
      host.fail(reason: 'NOPE.');
    }
  }
}

GameEngine buildEngine() => GameEngine(
      provider: FallbackChallengeProvider(
        scripted: ScriptedChallengeProvider(
          generator: ChallengeGenerator(
            templates: [
              ChallengeTemplate(
                id: 'stub',
                tag: ChallengeTag.color,
                build: _StubChallenge.new,
                starter: true,
              ),
            ],
            random: Random(1),
          ),
        ),
      ),
      random: Random(1),
    );

void tick(GameEngine e, int ms) {
  for (var i = 0; i < ms ~/ 16; i++) {
    e.tick(const Duration(milliseconds: 16));
  }
}

void main() {
  test('a run starts on an intro beat, then level 1', () {
    final engine = buildEngine();
    engine.startRun();
    expect(engine.state.phase, GamePhase.intro);
    expect(engine.state.level, 1);

    tick(engine, 600);
    expect(engine.state.phase, GamePhase.playing);
    expect(engine.state.challenge, isNotNull);
  });

  test('a correct answer flashes green then advances one level', () {
    final engine = buildEngine();
    engine.startRun();
    tick(engine, 600);

    engine.handleTap(const TapInfo(targetId: 'good', elapsed: Duration.zero));
    expect(engine.state.phase, GamePhase.correct);
    expect(engine.state.level, 1);

    tick(engine, 300);
    expect(engine.state.phase, GamePhase.playing);
    expect(engine.state.level, 2);
  });

  test('a mistake flashes red with a roast, then ends the run', () {
    final engine = buildEngine();
    engine.startRun();
    tick(engine, 600);

    engine.handleTap(const TapInfo(targetId: 'bad', elapsed: Duration.zero));
    expect(engine.state.phase, GamePhase.wrong);
    expect(engine.state.flashMessage, 'NOPE.');

    tick(engine, 2900);
    expect(engine.state.phase, GamePhase.gameOver);
  });

  test('tapping during the wrong flash skips straight to game over', () {
    final engine = buildEngine();
    engine.startRun();
    tick(engine, 600);

    engine.handleTap(const TapInfo(targetId: 'bad', elapsed: Duration.zero));
    expect(engine.state.phase, GamePhase.wrong);

    // Inside the skip grace: a stray tap must not swallow the roast.
    tick(engine, 200);
    engine.skipWrongFlash();
    expect(engine.state.phase, GamePhase.wrong);

    // Past the grace, nowhere near GameEngine.wrongFlash yet — only the
    // skip should move it.
    tick(engine, 400);
    expect(engine.state.phase, GamePhase.wrong);
    engine.skipWrongFlash();
    expect(engine.state.phase, GamePhase.gameOver);
  });

  test('skipWrongFlash does nothing outside the wrong phase', () {
    final engine = buildEngine();
    engine.startRun();
    tick(engine, 600);
    expect(engine.state.phase, GamePhase.playing);

    engine.skipWrongFlash();
    expect(engine.state.phase, GamePhase.playing);
  });

  test('running out of time ends the run', () {
    final engine = buildEngine();
    engine.startRun();
    tick(engine, 600);
    tick(engine, 2100);
    expect(engine.state.phase, GamePhase.wrong);
  });

  test('input is ignored outside the playing phase', () {
    final engine = buildEngine();
    engine.startRun();
    engine.handleTap(const TapInfo(targetId: 'good', elapsed: Duration.zero));
    expect(engine.state.phase, GamePhase.intro);
  });

  test('continue resumes the same level, once per run', () {
    final engine = buildEngine();
    engine.startRun();
    tick(engine, 600);
    tick(engine, 300); // level 1 -> wait
    engine.handleTap(const TapInfo(targetId: 'good', elapsed: Duration.zero));
    tick(engine, 300);
    expect(engine.state.level, 2);

    engine.handleTap(const TapInfo(targetId: 'bad', elapsed: Duration.zero));
    tick(engine, 2900);
    expect(engine.state.phase, GamePhase.gameOver);
    expect(engine.state.continueUsed, isFalse);

    engine.continueRun();
    // READY beat first, then the same level again.
    expect(engine.state.phase, GamePhase.intro);
    tick(engine, 600);
    expect(engine.state.phase, GamePhase.playing);
    expect(engine.state.level, 2);
    expect(engine.state.continueUsed, isTrue);
  });

  test('emits the events the UI layer listens to', () {
    final engine = buildEngine();
    final events = <GameEvent>[];
    engine.addEventListener((e, _) => events.add(e));

    engine.startRun();
    tick(engine, 600);
    engine.handleTap(const TapInfo(targetId: 'good', elapsed: Duration.zero));
    tick(engine, 300);
    engine.handleTap(const TapInfo(targetId: 'bad', elapsed: Duration.zero));
    tick(engine, 2900);

    expect(events.first, GameEvent.runStarted);
    expect(events, contains(GameEvent.correct));
    expect(events, contains(GameEvent.wrong));
    expect(events.last, GameEvent.gameOver);
  });

  test('pace note fires once, at level 6 (no timer) and level 10 (faster)',
      () {
    final engine = buildEngine();
    engine.startRun();
    tick(engine, 600); // level 1

    for (var level = 1; level <= 10; level++) {
      switch (level) {
        case 6:
          expect(engine.state.paceNote, 'NO MORE TIMER.');
        case 10:
          expect(engine.state.paceNote, 'FASTER NOW.');
        default:
          expect(engine.state.paceNote, isNull, reason: 'level $level');
      }
      engine
          .handleTap(const TapInfo(targetId: 'good', elapsed: Duration.zero));
      tick(engine, 300);
    }
  });

  group('difficulty', () {
    test('the first nine levels are a slow, stepped tutorial ramp', () {
      // Level 1-2 is the most generous the game ever is; each later step
      // through the tutorial only nudges the pace, never jumps it.
      expect(Difficulty.speedForLevel(1), 0.49);
      expect(Difficulty.speedForLevel(2), 0.49);
      expect(Difficulty.speedForLevel(3), 0.52);
      expect(Difficulty.speedForLevel(4), 0.52);
      expect(Difficulty.speedForLevel(5), 0.56);
      expect(Difficulty.speedForLevel(6), 0.56);
      expect(Difficulty.speedForLevel(9), 0.65);
      // Monotonically non-decreasing across every level 1-60, in steps: a
      // level never shares a step with a level more than 10 apart once
      // past the tutorial band.
      var previous = Difficulty.speedForLevel(1);
      for (var level = 2; level <= 60; level++) {
        final speed = Difficulty.speedForLevel(level);
        expect(speed, greaterThanOrEqualTo(previous), reason: 'level $level');
        previous = speed;
      }
    });

    test('speed steps every ten levels from level 10, capped below the old '
        'asymptote', () {
      expect(Difficulty.speedForLevel(10), Difficulty.speedForLevel(19));
      expect(Difficulty.speedForLevel(20), Difficulty.speedForLevel(29));
      expect(Difficulty.speedForLevel(19),
          lessThan(Difficulty.speedForLevel(20)));
      // The old formula capped at 2.35; the new tail stays gentler than that
      // forever, matching the "leave a bit more time" request.
      expect(Difficulty.speedForLevel(1000), lessThan(2.35));
      expect(Difficulty.speedForLevel(50), Difficulty.speedForLevel(1000));
    });

    test('timer bar disappears exactly when trick templates unlock', () {
      expect(Difficulty.showTimerBar(5), isTrue);
      expect(Difficulty.showTimerBar(6), isFalse);
      expect(Difficulty.allowsTricks(6), isTrue);
    });

    test('milestone key fires at level 6 (no timer) and level 10 (faster)',
        () {
      expect(Difficulty.milestoneKey(5), isNull);
      expect(Difficulty.milestoneKey(6), 'ui.game.milestone.no_timer');
      expect(Difficulty.milestoneKey(7), isNull);
      expect(Difficulty.milestoneKey(9), isNull);
      expect(Difficulty.milestoneKey(10), 'ui.game.milestone.faster');
      expect(Difficulty.milestoneKey(11), isNull);
    });
  });

  group('generator', () {
    test('only starter templates show up in the first three levels', () {
      final generator = ChallengeGenerator(
        templates: kChallengeTemplates,
        random: Random(42),
      );
      final starters =
          kChallengeTemplates.where((t) => t.starter).map((t) => t.id).toSet();
      for (var i = 0; i < 200; i++) {
        for (final level in [1, 2, 3]) {
          expect(starters, contains(generator.next(level).id));
        }
      }
    });

    test('never repeats the same template back to back', () {
      final generator = ChallengeGenerator(
        templates: kChallengeTemplates,
        random: Random(7),
      );
      String? previous;
      for (var level = 1; level <= 400; level++) {
        final id = generator.next(level).id;
        expect(id, isNot(previous));
        previous = id;
      }
    });

    test('locked templates never appear below their level', () {
      final generator = ChallengeGenerator(
        templates: kChallengeTemplates,
        random: Random(11),
      );
      final byId = {for (final t in kChallengeTemplates) t.id: t};
      for (var level = 1; level <= 60; level++) {
        for (var i = 0; i < 30; i++) {
          final id = generator.next(level).id;
          expect(byId[id]!.minLevel, lessThanOrEqualTo(level));
        }
      }
    });
  });
}
