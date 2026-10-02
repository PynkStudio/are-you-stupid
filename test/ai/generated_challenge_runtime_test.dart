import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:are_you_stupid/ai/generated_challenge.dart';
import 'package:are_you_stupid/ai/generated_challenge_runtime.dart';
import 'package:are_you_stupid/core/challenge.dart';
import 'package:are_you_stupid/i18n/app_locale.dart';

class _RecordingHost implements ChallengeHost {
  bool? passed;
  String? failReason;
  String? passNote;
  int invalidations = 0;

  @override
  void pass({String? note}) {
    passed = true;
    passNote = note;
  }

  @override
  void fail({String? reason}) {
    passed = false;
    failReason = reason;
  }

  @override
  void invalidate() => invalidations++;
}

void main() {
  group('buildFromProposal', () {
    test('wraps the runtime with ai provenance', () {
      final generated = buildFromProposal(_proposal(action: 'tap'));
      expect(generated.source, 'ai');
      expect(generated.id, 'ai.abc12');
      expect(generated.challenge, isA<GeneratedChallengeRuntime>());
      expect(generated.challenge.view.instruction, 'TAP THE ONLY BLUE');
    });
  });

  group('tap / color_pick: single named target wins', () {
    for (final action in ['tap', 'color_pick']) {
      test('$action: tapping the correct element passes', () {
        final c = GeneratedChallengeRuntime(
          _proposal(action: action),
          _params(),
        );
        final host = _RecordingHost();
        c.onTap(const TapInfo(targetId: 'e1', elapsed: Duration.zero), host);
        expect(host.passed, isTrue);
      });

      test('$action: tapping a decoy fails with the proposal fail line', () {
        final c = GeneratedChallengeRuntime(
          _proposal(action: action),
          _params(),
        );
        final host = _RecordingHost();
        c.onTap(const TapInfo(targetId: 'e2', elapsed: Duration.zero), host);
        expect(host.passed, isFalse);
        expect(host.failReason, 'THE ONLY BLUE WAS THE FIRST.');
      });

      test('$action: background tap is ignored', () {
        final c = GeneratedChallengeRuntime(
          _proposal(action: action),
          _params(),
        );
        final host = _RecordingHost();
        c.onTap(const TapInfo(targetId: null, elapsed: Duration.zero), host);
        expect(host.passed, isNull);
      });

      test('$action: timing out fails', () {
        final c = GeneratedChallengeRuntime(
          _proposal(action: action),
          _params(),
        );
        final host = _RecordingHost();
        c.onTimeout(host);
        expect(host.passed, isFalse);
        expect(host.failReason, 'THE ONLY BLUE WAS THE FIRST.');
      });
    }
  });

  group('donot_tap: the named element is the one to avoid', () {
    test('tapping the forbidden element fails', () {
      final c = GeneratedChallengeRuntime(
        _proposal(action: 'donot_tap'),
        _params(),
      );
      final host = _RecordingHost();
      c.onTap(const TapInfo(targetId: 'e1', elapsed: Duration.zero), host);
      expect(host.passed, isFalse);
    });

    test('tapping any other real element passes', () {
      final c = GeneratedChallengeRuntime(
        _proposal(action: 'donot_tap'),
        _params(),
      );
      final host = _RecordingHost();
      c.onTap(const TapInfo(targetId: 'e2', elapsed: Duration.zero), host);
      expect(host.passed, isTrue);
    });

    test('never tapping at all fails on timeout', () {
      final c = GeneratedChallengeRuntime(
        _proposal(action: 'donot_tap'),
        _params(),
      );
      final host = _RecordingHost();
      c.onTimeout(host);
      expect(host.passed, isFalse);
    });
  });

  group('hold: hold the named target through the whole duration', () {
    test('holding through timeout passes', () {
      final c = GeneratedChallengeRuntime(
        _proposal(action: 'hold'),
        _params(),
      );
      final host = _RecordingHost();
      c.onTap(const TapInfo(targetId: 'e1', elapsed: Duration.zero), host);
      expect(host.passed, isNull); // still pending
      c.onTimeout(host);
      expect(host.passed, isTrue);
    });

    test('releasing early fails', () {
      final c = GeneratedChallengeRuntime(
        _proposal(action: 'hold'),
        _params(),
      );
      final host = _RecordingHost();
      c.onTap(const TapInfo(targetId: 'e1', elapsed: Duration.zero), host);
      c.onTap(
        const TapInfo(
          targetId: 'e1',
          elapsed: Duration(milliseconds: 100),
          kind: TapKind.up,
        ),
        host,
      );
      expect(host.passed, isFalse);
    });

    test('pressing the wrong target fails immediately', () {
      final c = GeneratedChallengeRuntime(
        _proposal(action: 'hold'),
        _params(),
      );
      final host = _RecordingHost();
      c.onTap(const TapInfo(targetId: 'e2', elapsed: Duration.zero), host);
      expect(host.passed, isFalse);
    });

    test('never holding fails on timeout', () {
      final c = GeneratedChallengeRuntime(
        _proposal(action: 'hold'),
        _params(),
      );
      final host = _RecordingHost();
      c.onTimeout(host);
      expect(host.passed, isFalse);
    });
  });

  group('tap_many: tap every element except the excluded one', () {
    test('tapping the excluded element fails immediately', () {
      final c = GeneratedChallengeRuntime(
        _proposal(action: 'tap_many', elementCount: 3),
        _params(),
      );
      final host = _RecordingHost();
      c.onTap(const TapInfo(targetId: 'e1', elapsed: Duration.zero), host);
      expect(host.passed, isFalse);
    });

    test('tapping every other element passes on the last one', () {
      final c = GeneratedChallengeRuntime(
        _proposal(action: 'tap_many', elementCount: 3),
        _params(),
      );
      final host = _RecordingHost();
      c.onTap(const TapInfo(targetId: 'e2', elapsed: Duration.zero), host);
      expect(host.passed, isNull);
      expect(host.invalidations, 1);
      c.onTap(const TapInfo(targetId: 'e3', elapsed: Duration.zero), host);
      expect(host.passed, isTrue);
    });
  });

  group('tap_sequence: tap elements in proposal order', () {
    test('tapping in order passes on the last element', () {
      final c = GeneratedChallengeRuntime(
        _proposal(action: 'tap_sequence', elementCount: 3),
        _params(),
      );
      final host = _RecordingHost();
      c.onTap(const TapInfo(targetId: 'e1', elapsed: Duration.zero), host);
      expect(host.passed, isNull);
      c.onTap(const TapInfo(targetId: 'e2', elapsed: Duration.zero), host);
      expect(host.passed, isNull);
      c.onTap(const TapInfo(targetId: 'e3', elapsed: Duration.zero), host);
      expect(host.passed, isTrue);
    });

    test('tapping out of order fails', () {
      final c = GeneratedChallengeRuntime(
        _proposal(action: 'tap_sequence', elementCount: 3),
        _params(),
      );
      final host = _RecordingHost();
      c.onTap(const TapInfo(targetId: 'e2', elapsed: Duration.zero), host);
      expect(host.passed, isFalse);
    });
  });

  group('tap_until_stop: repeat-tap the named target to a goal', () {
    test('reaching the goal (level 1 => 6 taps) passes', () {
      final c = GeneratedChallengeRuntime(
        _proposal(action: 'tap_until_stop'),
        _params(),
      );
      final host = _RecordingHost();
      for (var i = 0; i < 5; i++) {
        c.onTap(const TapInfo(targetId: 'e1', elapsed: Duration.zero), host);
        expect(host.passed, isNull);
      }
      c.onTap(const TapInfo(targetId: 'e1', elapsed: Duration.zero), host);
      expect(host.passed, isTrue);
    });

    test('a tap on another element is ignored, not counted', () {
      final c = GeneratedChallengeRuntime(
        _proposal(action: 'tap_until_stop', elementCount: 2),
        _params(),
      );
      final host = _RecordingHost();
      c.onTap(const TapInfo(targetId: 'e2', elapsed: Duration.zero), host);
      expect(host.passed, isNull);
      expect(host.invalidations, 0);
    });

    test('not reaching the goal fails on timeout', () {
      final c = GeneratedChallengeRuntime(
        _proposal(action: 'tap_until_stop'),
        _params(),
      );
      final host = _RecordingHost();
      c.onTap(const TapInfo(targetId: 'e1', elapsed: Duration.zero), host);
      c.onTimeout(host);
      expect(host.passed, isFalse);
    });
  });

  group('rendering', () {
    test('elements map 1:1 to targets, layout follows element count', () {
      final c = GeneratedChallengeRuntime(
        _proposal(action: 'tap', elementCount: 4),
        _params(),
      );
      expect(c.view.targets.length, 4);
      expect(c.view.layout, ChallengeLayout.grid2x2);
      expect(c.view.targets.first.id, 'e1');
    });

    test('a single-element proposal lays out as single', () {
      final c = GeneratedChallengeRuntime(
        _proposal(action: 'hold', elementCount: 1),
        _params(),
      );
      expect(c.view.layout, ChallengeLayout.single);
    });

    test('duration comes straight from difficulty.timeLimitMs', () {
      final c = GeneratedChallengeRuntime(
        _proposal(action: 'tap'),
        _params(),
      );
      expect(c.duration, const Duration(milliseconds: 2500));
    });
  });
}

ChallengeParams _params() => ChallengeParams(
      level: 1,
      rng: Random(1),
      speed: 1.0,
      locale: AppLocale.en,
    );

ChallengeProposal _proposal({required String action, int elementCount = 1}) {
  final elements = [
    for (var i = 1; i <= elementCount; i++)
      {
        'id': 'e$i',
        'label': 'E$i',
        'color': i == 1 ? 'blue' : 'red',
        'shape': 'circle',
        'scale': 1.0,
        'rotation': 0,
        'dx': 0,
        'dy': 0,
        'opacity': 1.0,
        'hidden': false,
      },
  ];
  return ChallengeProposal.fromJson({
    'id': 'ai.abc12',
    'mechanic': {
      'move': 'tap_true_color',
      'action': action,
      'kind': 'mixed',
      'sense_decoys': <String>[],
    },
    'instruction': 'TAP THE ONLY BLUE',
    'elements': elements,
    'correctAnswer': {'elementId': 'e1', 'startsCorrect': false},
    'difficulty': {'level': 1, 'timeLimitMs': 2500, 'trickType': 'none'},
    'failLine': {'en': 'THE ONLY BLUE WAS THE FIRST.'},
    'seed': 1,
    'source': 'ai',
  });
}
