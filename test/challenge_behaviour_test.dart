import 'dart:math';

import 'package:are_you_stupid/challenges/color_challenges.dart';
import 'package:are_you_stupid/challenges/counting_challenges.dart';
import 'package:are_you_stupid/challenges/memory_challenges.dart';
import 'package:are_you_stupid/challenges/patience_challenges.dart';
import 'package:are_you_stupid/challenges/trick_challenges.dart';
import 'package:are_you_stupid/core/challenge.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_host.dart';

ChallengeParams params({int level = 10, int seed = 3, double speed = 1.0}) =>
    ChallengeParams(level: level, rng: Random(seed), speed: speed);

void main() {
  group('TAP <COLOR>', () {
    test('the button painted with the named color wins', () {
      final c = buildTapColor(params());
      final wanted = c.view.instruction.split(' ').last;
      final correct =
          c.view.targets.firstWhere((t) => t.color.label == wanted);
      final host = FakeHost();
      c.onTap(tapOn(correct.id), host);
      expect(host.passed, isTrue);
    });

    test('any other button loses', () {
      final c = buildTapColor(params());
      final wanted = c.view.instruction.split(' ').last;
      final wrong = c.view.targets.firstWhere((t) => t.color.label != wanted);
      final host = FakeHost();
      c.onTap(tapOn(wrong.id), host);
      expect(host.failed, isTrue);
    });
  });

  group("DON'T TAP ANYTHING", () {
    test('doing nothing wins, and the bait shows up on the way', () {
      final c = DontTapChallenge(params());
      final host = FakeHost();
      c.onStart(host);
      expect(c.view.targets, isEmpty);
      advance(c, host, to: c.duration);
      expect(host.passed, isTrue);
    });

    test('tapping the bait loses', () {
      final c = DontTapChallenge(params());
      final host = FakeHost();
      c.onStart(host);
      advance(
        c,
        host,
        to: Duration(milliseconds: c.duration.inMilliseconds ~/ 2),
      );
      expect(c.view.targets, isNotEmpty, reason: 'bait should be visible');
      c.onTap(tapOn('bait'), host);
      expect(host.failed, isTrue);
      expect(host.reason, 'YOU HAD ONE JOB.');
    });
  });

  group('TAP TWICE', () {
    test('exactly two taps wins after the settle window', () {
      final c = ExactTapsChallenge.twice(params());
      final host = FakeHost();
      c.onTap(tapOn('pad', at: const Duration(milliseconds: 100)), host);
      c.onTap(tapOn('pad', at: const Duration(milliseconds: 200)), host);
      expect(host.settled, isFalse);
      advance(c, host, to: const Duration(milliseconds: 900));
      expect(host.passed, isTrue);
    });

    test('a third tap loses immediately', () {
      final c = ExactTapsChallenge.twice(params());
      final host = FakeHost();
      for (var i = 0; i < 3; i++) {
        c.onTap(tapOn('pad', at: Duration(milliseconds: 60 * i)), host);
      }
      expect(host.failed, isTrue);
      expect(host.reason, 'TOO MANY.');
    });

    test('one tap loses on timeout', () {
      final c = ExactTapsChallenge.twice(params());
      final host = FakeHost();
      c.onTap(tapOn('pad'), host);
      c.onTimeout(host);
      expect(host.failed, isTrue);
      expect(host.reason, 'NOT ENOUGH.');
    });
  });

  group('TAP AFTER N SECONDS', () {
    test('inside the tolerance wins and reports the error', () {
      final c = PreciseTimingChallenge(
        params(),
        const Duration(seconds: 2),
        const Duration(milliseconds: 400),
      );
      final host = FakeHost();
      c.onTap(tapOn('bg', at: const Duration(milliseconds: 2130)), host);
      expect(host.passed, isTrue);
      expect(host.note, '+0.13s');
    });

    test('too early loses and reports the error', () {
      final c = PreciseTimingChallenge(
        params(),
        const Duration(seconds: 2),
        const Duration(milliseconds: 400),
      );
      final host = FakeHost();
      c.onTap(tapOn('bg', at: const Duration(milliseconds: 900)), host);
      expect(host.failed, isTrue);
      expect(host.reason, '-1.10s OFF.');
    });
  });

  group('WAIT FOR GREEN', () {
    test('tapping before green is impatience', () {
      final c = WaitForGreenChallenge.build(params());
      final host = FakeHost();
      c.onTap(tapOn('pad'), host);
      expect(host.failed, isTrue);
      expect(host.reason, 'IMPATIENT.');
    });

    test('tapping after green wins', () {
      final c = WaitForGreenChallenge.build(params());
      final host = FakeHost();
      advance(
        c,
        host,
        to: c.duration - const Duration(milliseconds: 100),
      );
      c.onTap(tapOn('pad'), host);
      expect(host.passed, isTrue);
    });
  });

  group('HOLD THE BUTTON', () {
    test('letting go loses', () {
      final c = HoldButtonChallenge(params());
      final host = FakeHost();
      c.onTap(const TapInfo(targetId: 'pad', elapsed: Duration.zero), host);
      c.onTap(
        const TapInfo(
          targetId: 'pad',
          elapsed: Duration(milliseconds: 300),
          kind: TapKind.up,
        ),
        host,
      );
      expect(host.failed, isTrue);
      expect(host.reason, 'YOU LET GO.');
    });

    test('holding until the end wins', () {
      final c = HoldButtonChallenge(params());
      final host = FakeHost();
      c.onTap(const TapInfo(targetId: 'pad', elapsed: Duration.zero), host);
      c.onTimeout(host);
      expect(host.passed, isTrue);
    });

    test('never pressing loses', () {
      final c = HoldButtonChallenge(params());
      final host = FakeHost();
      c.onTimeout(host);
      expect(host.failed, isTrue);
      expect(host.reason, 'HOLD MEANS HOLD.');
    });
  });

  group('LEFT / RIGHT', () {
    test('the answer follows the position at tap time, not the button', () {
      final c = LeftRightSwapChallenge(params());
      final host = FakeHost();
      final wantsLeft = c.view.instruction == 'TAP LEFT';
      // Tap the button currently sitting on the wanted side.
      c.onTap(
        tapOn(c.view.targets[wantsLeft ? 0 : 1].id,
            index: wantsLeft ? 0 : 1),
        host,
      );
      expect(host.passed, isTrue);
    });
  });

  group('IGNORE THE NEXT LINE', () {
    test('obeying the ignored line loses', () {
      final c = buildIgnoreNext(params());
      final banned = c.view.hint!.split(' ').last;
      final trap = c.view.targets.firstWhere((t) => t.color.label == banned);
      final host = FakeHost();
      c.onTap(tapOn(trap.id), host);
      expect(host.failed, isTrue);
    });

    test('any other button wins', () {
      final c = buildIgnoreNext(params());
      final banned = c.view.hint!.split(' ').last;
      final ok = c.view.targets.firstWhere((t) => t.color.label != banned);
      final host = FakeHost();
      c.onTap(tapOn(ok.id), host);
      expect(host.passed, isTrue);
    });
  });

  group('MEMORY', () {
    test('taps during the show phase are ignored, then the color wins', () {
      final c = RememberColorChallenge(params());
      final host = FakeHost();
      c.onStart(host);
      final secret = c.view.targets.single.color;

      c.onTap(tapOn('show'), host);
      expect(host.settled, isFalse, reason: 'no input during memorising');

      advance(c, host, to: const Duration(milliseconds: 1400));
      expect(c.view.instruction, 'TAP THE COLOR');
      final correct =
          c.view.targets.firstWhere((t) => t.color == secret);
      c.onTap(tapOn(correct.id), host);
      expect(host.passed, isTrue);
    });
  });

  group('MOVING BUTTONS', () {
    test('the targets actually move but keep their ids', () {
      final c = MovingColorChallenge.build(params());
      final host = FakeHost();
      final before = c.view.targets.map((t) => t.id).toList();
      advance(c, host, to: const Duration(milliseconds: 400));
      final after = c.view.targets;
      expect(after.map((t) => t.id).toList(), before);
      expect(after.any((t) => t.dx != 0 || t.dy != 0), isTrue);
    });
  });
}
