import 'dart:math';

import 'package:are_you_stupid/challenges/registry.dart';
import 'package:are_you_stupid/core/challenge.dart';
import 'package:are_you_stupid/core/challenge_generator.dart';
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

    tick(engine, 900);
    expect(engine.state.phase, GamePhase.gameOver);
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
    tick(engine, 900);
    expect(engine.state.phase, GamePhase.gameOver);
    expect(engine.state.continueUsed, isFalse);

    engine.continueRun();
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
    tick(engine, 900);

    expect(events.first, GameEvent.runStarted);
    expect(events, contains(GameEvent.correct));
    expect(events, contains(GameEvent.wrong));
    expect(events.last, GameEvent.gameOver);
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
