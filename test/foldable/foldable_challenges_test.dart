// The five UNFOLD YOUR BRAIN challenges, driven headless through the same
// normalized events the simulator and the iOS bridge produce.
import 'dart:math';

import 'package:are_you_stupid/challenges/foldable_challenges.dart';
import 'package:are_you_stupid/core/challenge.dart';
import 'package:are_you_stupid/core/foldable.dart';
import 'package:are_you_stupid/i18n/app_locale.dart';
import 'package:are_you_stupid/i18n/strings.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_host.dart';

ChallengeParams _p({int seed = 1, AppLocale locale = AppLocale.en}) =>
    ChallengeParams(level: 10, rng: Random(seed), speed: 1, locale: locale);

String _en(String key) => Strings.t(AppLocale.en, key);

/// Feeds a state transition as the controller would.
void _move(Challenge c, FakeHost h, FoldableState from, FoldableState to) {
  for (final e in HingeNormalizer.diff(from, to)) {
    c.onDeviceEvent(e, h);
  }
}

void _start(Challenge c, FakeHost h, FoldableState s) {
  c.onStart(h);
  c.onDeviceEvent(
    FoldableEvent(FoldableEventKind.initialState, previous: s, current: s),
    h,
  );
}

const _flat = FoldableState(
  status: HingeStatus.fullyOpen,
  angleDegrees: 180,
  display: DisplayConfiguration.expanded,
);
const _closed = FoldableState(
  status: HingeStatus.closed,
  angleDegrees: 0,
  display: DisplayConfiguration.compact,
);
FoldableState _at(double a) => FoldableState(
  status: FoldThresholds.standard.statusForAngle(a),
  angleDegrees: a,
  display: DisplayConfiguration.expanded,
);

void main() {
  group('BEND OVER', () {
    test('passes inside the ~90° window, with its host quip', () {
      final c = BendOverChallenge(_p());
      final h = FakeHost();
      _start(c, h, _flat);
      _move(c, h, _flat, _at(150)); // partially open, but not "bent"
      expect(h.settled, isFalse);
      _move(c, h, _at(150), _at(95));
      expect(h.passed, isTrue);
      expect(c.successQuip, _en('fold.bend_over.quip'));
    });

    test('status-only hardware: any partial fold counts', () {
      final c = BendOverChallenge(_p());
      final h = FakeHost();
      const open = FoldableState(status: HingeStatus.fullyOpen);
      _start(c, h, open);
      _move(c, h, open, const FoldableState(status: HingeStatus.partiallyOpen));
      expect(h.passed, isTrue);
    });

    test('tapping or waiting fails with an explainable line', () {
      final tapped = FakeHost();
      BendOverChallenge(_p()).onTap(tapBackground(), tapped);
      expect(tapped.reason, _en('fold.bend_over.tap'));
      final c = BendOverChallenge(_p());
      final waited = FakeHost();
      _start(c, waited, _flat);
      advance(c, waited, to: c.duration);
      expect(waited.reason, _en('fold.bend_over.fail'));
      expect(c.view.hint, _en('fold.bend_over.hint'));
    });

    test('rounds never shrink below the physical minimum', () {
      final fast = ChallengeParams(level: 99, rng: Random(1), speed: 6);
      expect(
        BendOverChallenge(fast).duration,
        FoldThresholds.standard.minPhysicalRound,
      );
    });
  });

  group("DON'T OPEN IT", () {
    test('waiting it out passes', () {
      final c = DontOpenChallenge(_p());
      final h = FakeHost();
      _start(c, h, _closed);
      c.onTap(tapBackground(), h); // background isn't the button
      advance(c, h, to: c.duration);
      expect(h.passed, isTrue);
      expect(c.successQuip, _en('fold.dont_open.quip'));
    });

    test('opening the phone or pressing OPEN fails', () {
      final c = DontOpenChallenge(_p());
      final h = FakeHost();
      _start(c, h, _closed);
      _move(c, h, _closed, _at(120));
      expect(h.reason, _en('fold.dont_open.fail'));
      final h2 = FakeHost();
      DontOpenChallenge(_p()).onTap(tapOn('open'), h2);
      expect(h2.reason, _en('fold.dont_open.fail'));
    });
  });

  group('CRACK THE CODE', () {
    test('angle variant: hold the secret angle to unlock', () {
      final c = CrackTheCodeChallenge(_p());
      final h = FakeHost();
      _start(c, h, _flat);
      final target = c.targetAngle!;
      expect(
        (target - 180).abs(),
        greaterThan(FoldThresholds.standard.safeTolerance * 2),
      );
      _move(c, h, _flat, _at(target + 5));
      expect(c.view.device!.pulse, greaterThan(0)); // warmer → haptic tick
      // Sweeping through doesn't count; holding does.
      c.onTick(const Duration(milliseconds: 100), h);
      expect(h.settled, isFalse);
      c.onTick(const Duration(milliseconds: 800), h);
      expect(h.passed, isTrue);
      expect(c.view.device!.solved, isTrue);
    });

    test('leaving the target resets the hold', () {
      final c = CrackTheCodeChallenge(_p(seed: 3));
      final h = FakeHost();
      _start(c, h, _flat);
      final t = c.targetAngle!;
      _move(c, h, _flat, _at(t));
      c.onTick(const Duration(milliseconds: 300), h);
      _move(c, h, _at(t), _at(t > 100 ? t - 40 : t + 40));
      c.onTick(const Duration(milliseconds: 1200), h);
      expect(h.settled, isFalse);
    });

    test('state variant: the other open status, held longer', () {
      final c = CrackTheCodeChallenge(_p());
      final h = FakeHost();
      const open = FoldableState(status: HingeStatus.fullyOpen);
      const half = FoldableState(status: HingeStatus.partiallyOpen);
      _start(c, h, open);
      expect(c.usesAngle, isFalse);
      expect(c.targetStatus, HingeStatus.partiallyOpen);
      c.onTick(const Duration(milliseconds: 100), h);
      _move(c, h, open, half);
      c.onTick(const Duration(milliseconds: 800), h);
      expect(h.settled, isFalse);
      c.onTick(const Duration(milliseconds: 1200), h);
      expect(h.passed, isTrue);
    });

    test('poking the safe fails', () {
      final h = FakeHost();
      CrackTheCodeChallenge(_p()).onTap(tapBackground(), h);
      expect(h.reason, _en('fold.crack_the_code.tap'));
    });
  });

  group('THE OTHER SIDE', () {
    test('switch displays, then tap the revealed code', () {
      final c = OtherSideChallenge(_p());
      final h = FakeHost();
      _start(c, h, _flat);
      expect(c.view.device!.revealed, isFalse);
      _move(c, h, _flat, _flat.copyWith(display: DisplayConfiguration.compact));
      expect(c.view.device!.label, '${c.missing}');
      c.onTap(tapOn('d${c.missing}'), h);
      expect(h.passed, isTrue);
    });

    test('guessing before looking fails, even when lucky', () {
      final c = OtherSideChallenge(_p());
      final h = FakeHost();
      _start(c, h, _flat);
      c.onTap(tapOn('d${c.missing}'), h);
      expect(h.reason, _en('fold.other_side.guess'));
    });

    test('repeated switches keep the reveal; wrong code fails', () {
      final c = OtherSideChallenge(_p(seed: 9));
      final h = FakeHost();
      _start(c, h, _flat);
      var s = _flat;
      for (var i = 0; i < 10; i++) {
        final next = s.copyWith(
          display: s.display == DisplayConfiguration.expanded
              ? DisplayConfiguration.compact
              : DisplayConfiguration.expanded,
        );
        _move(c, h, s, next);
        s = next;
      }
      expect(c.switches, 10);
      expect(c.revealed, isTrue);
      final wrong = c.view.targets.firstWhere((t) => t.id != 'd${c.missing}');
      c.onTap(tapOn(wrong.id), h);
      expect(h.reason, _en('fold.other_side.wrong'));
    });

    test('timeout uses the two-sides line', () {
      final c = OtherSideChallenge(_p());
      final h = FakeHost();
      advance(c, h, to: c.duration);
      expect(h.reason, _en('fold.other_side.fail'));
    });
  });

  group('OPEN YOUR MIND', () {
    test('fully open shows the decoy; half open shows the answer', () {
      final c = OpenYourMindChallenge(_p());
      final h = FakeHost();
      _start(c, h, _flat);
      expect(c.view.device!.label, contains(_en('fold.shape.${c.decoy.name}')));
      _move(c, h, _flat, _at(100));
      expect(c.view.device!.revealed, isTrue);
      expect(
        c.view.device!.label,
        contains(_en('fold.shape.${c.answer.name}')),
      );
      c.onTap(tapOn(c.answer.name), h);
      expect(h.passed, isTrue);
      expect(c.successQuip, _en('fold.open_your_mind.quip'));
    });

    test('right shape while too open, or the decoy, fails', () {
      final c = OpenYourMindChallenge(_p());
      final h = FakeHost();
      _start(c, h, _flat);
      c.onTap(tapOn(c.answer.name), h);
      expect(h.reason, _en('fold.open_your_mind.too_open'));
      final c2 = OpenYourMindChallenge(_p());
      final h2 = FakeHost();
      _start(c2, h2, _at(100));
      c2.onTap(tapOn(c2.decoy.name), h2);
      expect(h2.reason, _en('fold.open_your_mind.wrong'));
    });
  });

  group('every foldable challenge', () {
    test('skips — never fails — when the hinge disappears', () {
      for (final t in kFoldableChallengeTemplates) {
        final c = t.build(_p());
        final h = FakeHost();
        _start(c, h, _flat);
        _move(c, h, _flat, FoldableState.unknown);
        expect(h.passed, isTrue, reason: t.id);
        expect(h.note, _en('fold.common.skipped'), reason: t.id);
      }
    });

    test('instructions stay under 8 words, uppercase, in every language', () {
      for (final locale in AppLocale.values) {
        for (final t in kFoldableChallengeTemplates) {
          final text = t.build(_p(locale: locale)).view.instruction;
          expect(
            text.split(RegExp(r'\s+')).length,
            lessThanOrEqualTo(8),
            reason: '$locale ${t.id}',
          );
          expect(text, text.toUpperCase(), reason: '$locale ${t.id}');
        }
      }
    });

    test('never a starter, never before level 4, all declare hardware', () {
      for (final t in kFoldableChallengeTemplates) {
        expect(t.starter, isFalse);
        expect(t.minLevel, greaterThanOrEqualTo(4));
        expect(t.needsHardware, isTrue);
      }
    });
  });
}
