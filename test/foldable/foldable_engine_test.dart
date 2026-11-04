// Engine + generator integration: eligibility, event routing, timers,
// host quips, the commentary tracker, and the simulator panel.
import 'dart:math';

import 'package:are_you_stupid/ai/foldable_commentary.dart';
import 'package:are_you_stupid/ai/generated_challenge.dart';
import 'package:are_you_stupid/ai/providers.dart';
import 'package:are_you_stupid/challenges/foldable_challenges.dart';
import 'package:are_you_stupid/challenges/registry.dart';
import 'package:are_you_stupid/core/challenge.dart';
import 'package:are_you_stupid/core/challenge_generator.dart';
import 'package:are_you_stupid/core/foldable.dart';
import 'package:are_you_stupid/core/game_engine.dart';
import 'package:are_you_stupid/core/game_state.dart';
import 'package:are_you_stupid/i18n/app_locale.dart';
import 'package:are_you_stupid/ui/widgets/foldable_simulator_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
final _foldIds = {for (final t in kFoldableChallengeTemplates) t.id};

ChallengeGenerator _gen(
  DeviceCapabilities caps,
  FoldableState state, {
  int seed = 1,
}) => ChallengeGenerator(
  templates: soloTemplates(kChallengeTemplates),
  random: Random(seed),
  capabilities: () => caps,
  deviceState: () => state,
);

/// A provider that always serves one template.
class _Only implements ChallengeProvider {
  _Only(this.build);
  final Challenge Function(ChallengeParams) build;
  @override
  GeneratedChallenge? next(ChallengeContext context) => GeneratedChallenge(
    challenge: build(
      ChallengeParams(level: context.level, rng: Random(1), speed: 1),
    ),
    source: 'scripted',
  );
  @override
  void reset() {}
}

GameEngine _engineWith(
  Challenge Function(ChallengeParams) build,
  FoldableState device,
) {
  final e = GameEngine(provider: _Only(build))..deviceState = device;
  e.startRun();
  e.tick(GameEngine.introDuration);
  expect(e.state.phase, GamePhase.playing);
  return e;
}

void main() {
  group('eligibility', () {
    test('a conventional phone never gets a foldable challenge', () {
      final g = _gen(DeviceCapabilities.none, FoldableState.unknown);
      for (var level = 1; level < 60; level++) {
        expect(_foldIds.contains(g.next(level).id), isFalse);
      }
    });

    test('a foldable gets them — never back to back, never in levels 1–3', () {
      final g = _gen(DeviceCapabilities.simulated, _flat, seed: 4);
      var seen = 0;
      var last = false;
      for (var i = 0; i < 400; i++) {
        final level = 1 + i % 30;
        final isFold = _foldIds.contains(g.next(level).id);
        if (level <= 3) expect(isFold, isFalse);
        if (isFold) {
          seen++;
          expect(last, isFalse, reason: 'two physical rounds in a row');
        }
        last = isFold;
      }
      expect(seen, greaterThan(10));
    });

    test('initial conditions: DO NOT OPEN only from a closed phone', () {
      final dontOpen = kFoldableChallengeTemplates.firstWhere(
        (t) => t.id == 'dont_open',
      );
      final bend = kFoldableChallengeTemplates.firstWhere(
        (t) => t.id == 'bend_over',
      );
      expect(
        dontOpen.eligibleOn(DeviceCapabilities.simulated, _closed),
        isTrue,
      );
      expect(dontOpen.eligibleOn(DeviceCapabilities.simulated, _flat), isFalse);
      expect(
        bend.eligibleOn(
          DeviceCapabilities.simulated,
          const FoldableState(status: HingeStatus.partiallyOpen),
        ),
        isFalse,
      );
      expect(
        bend.eligibleOn(DeviceCapabilities.simulated, FoldableState.unknown),
        isFalse,
      );
    });

    test('THE OTHER SIDE stays simulator-only on approximated hardware', () {
      const hw = DeviceCapabilities({
        DeviceCapability.foldState: CapabilitySupport.official,
        DeviceCapability.displayConfiguration: CapabilitySupport.approximated,
      });
      final other = kFoldableChallengeTemplates.firstWhere(
        (t) => t.id == 'other_side',
      );
      expect(other.eligibleOn(hw, _flat), isFalse);
      expect(other.eligibleOn(DeviceCapabilities.simulated, _flat), isTrue);
      expect(
        other.eligibleOn(
          DeviceCapabilities.simulated,
          const FoldableState(status: HingeStatus.fullyOpen),
        ),
        isFalse,
      );
    });

    test('classic templates are unaffected by hardware', () {
      for (final t in kChallengeTemplates) {
        expect(t.needsHardware, isFalse);
        expect(
          t.eligibleOn(DeviceCapabilities.none, FoldableState.unknown),
          isTrue,
        );
      }
    });
  });

  group('engine', () {
    test('the round starts with the device state, then follows events', () {
      final e = _engineWith(BendOverChallenge.new, _flat);
      final half = _flat.copyWith(
        status: HingeStatus.partiallyOpen,
        angleDegrees: 90,
      );
      for (final ev in HingeNormalizer.diff(_flat, half)) {
        e.handleDeviceEvent(ev);
      }
      expect(e.state.phase, GamePhase.correct);
      expect(e.deviceState, half);
      // The quip lands on the next round's header, not on the 240 ms flash.
      e.tick(GameEngine.correctFlash);
      expect(e.state.hostQuip, isNotNull);
      e.tick(const Duration(milliseconds: 16));
      e.handleTap(const TapInfo(targetId: null, elapsed: Duration.zero));
      e.tick(GameEngine.wrongFlash);
      e.startRun();
      e.tick(GameEngine.introDuration);
      expect(e.state.hostQuip, isNull);
    });

    test('device events never touch the clock', () {
      final e = _engineWith(OtherSideChallenge.new, _flat);
      e.tick(const Duration(milliseconds: 500));
      var s = _flat;
      for (var i = 0; i < 30; i++) {
        final next = s.copyWith(
          display: i.isEven
              ? DisplayConfiguration.compact
              : DisplayConfiguration.expanded,
        );
        for (final ev in HingeNormalizer.diff(s, next)) {
          e.handleDeviceEvent(ev);
        }
        s = next;
      }
      expect(e.state.elapsed, const Duration(milliseconds: 500));
      expect(e.state.phase, GamePhase.playing);
    });

    test('events outside play update the state but reach no challenge', () {
      final e = GameEngine(provider: _Only(BendOverChallenge.new));
      e.handleDeviceEvent(
        const FoldableEvent(
          FoldableEventKind.deviceClosed,
          previous: _flat,
          current: _closed,
        ),
      );
      expect(e.deviceState, _closed);
      expect(e.state.phase, GamePhase.idle);
    });

    test('hinge loss mid-round skips without costing the run', () {
      final e = _engineWith(CrackTheCodeChallenge.new, _flat);
      e.handleDeviceEvent(
        const FoldableEvent(
          FoldableEventKind.hingeUnavailable,
          previous: _flat,
          current: FoldableState.unknown,
        ),
      );
      expect(e.state.phase, GamePhase.correct);
    });

    test('lifecycle gaps clamp to one frame — timers cannot be corrupted', () {
      expect(
        GameEngine.safeDelta(const Duration(seconds: 30)),
        const Duration(milliseconds: 16),
      );
      expect(
        GameEngine.safeDelta(const Duration(milliseconds: 20)),
        const Duration(milliseconds: 20),
      );
      expect(
        GameEngine.safeDelta(const Duration(milliseconds: -5)),
        Duration.zero,
      );
    });
  });

  group('host commentary', () {
    FoldableRoundSummary run(
      Challenge c,
      void Function(FoldableRoundTracker) act, {
      bool passed = false,
    }) {
      final t = FoldableRoundTracker()..startRound(c);
      act(t);
      return t.finish(
        passed: passed,
        elapsed: const Duration(milliseconds: 3200),
      );
    }

    FoldableEvent ev(FoldableEventKind k) =>
        FoldableEvent(k, previous: _flat, current: _flat);
    final params = ChallengeParams(level: 9, rng: Random(1), speed: 1);

    test('knows what was expected and what the player tried', () {
      final s = run(
        BendOverChallenge(params),
        (t) => t
          ..recordTap()
          ..recordTap(),
      );
      expect(s.expected, ExpectedInteraction.partialFold);
      expect(s.attempted, 'tap');
      expect(s.asidePool, 'fold.host.tapped_instead');
      final ctx = s.toContext();
      expect(ctx['expectedPhysicalAction'], 'fold the phone halfway');
      expect(ctx['secondsTaken'], '3.2');
    });

    test('flapping the hinge gets its own joke', () {
      final s = run(BendOverChallenge(params), (t) {
        for (var i = 0; i < 3; i++) {
          t.recordEvent(ev(FoldableEventKind.deviceOpened));
          t.recordEvent(ev(FoldableEventKind.deviceClosed));
        }
      });
      expect(s.flapping, isTrue);
      expect(s.asidePool, 'fold.host.flapping');
      expect(scriptedAside(s, AppLocale.it, Random(1)), isNotEmpty);
    });

    test(
      'folding during a classic challenge is "needless"; quiet otherwise',
      () {
        final classic = kChallengeTemplates.first.build(params);
        final folded = run(
          classic,
          (t) => t.recordEvent(ev(FoldableEventKind.hingeAngleChanged)),
        );
        expect(folded.isHardwareRound, isFalse);
        expect(folded.asidePool, 'fold.host.needless_fold');
        expect(run(classic, (t) => t.recordTap()).asidePool, isNull);
        expect(
          run(BendOverChallenge(params), (_) {}, passed: true).asidePool,
          isNull,
        );
      },
    );

    test('counts repeated hardware fails across a run', () {
      final t = FoldableRoundTracker();
      for (var i = 0; i < 3; i++) {
        t.startRound(BendOverChallenge(params));
        t.finish(passed: false, elapsed: Duration.zero);
      }
      t.startRound(BendOverChallenge(params));
      expect(
        t.finish(passed: false, elapsed: Duration.zero).hardwareFailsThisRun,
        4,
      );
    });
  });

  testWidgets('the simulator panel drives the shared controller', (
    tester,
  ) async {
    final sim = SimulatedHingeProvider();
    final device = FoldableDeviceController(
      hinge: sim,
      displayIsSimulated: true,
    )..setDisplay(DisplayConfiguration.expanded);
    final kinds = <FoldableEventKind>[];
    device.events.listen((e) => kinds.add(e.kind));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FoldableSimulatorPanel(hinge: sim, device: device),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('fold-sim-CLOSE')));
    await tester.pump();
    expect(device.state.status, HingeStatus.closed);
    expect(device.state.display, DisplayConfiguration.compact);
    await tester.tap(find.byKey(const ValueKey('fold-sim-OPEN')));
    await tester.tap(find.byKey(const ValueKey('fold-sim-LOSE HINGE')));
    await tester.tap(find.byKey(const ValueKey('fold-sim-RESET')));
    await tester.pump();
    expect(
      kinds,
      containsAllInOrder([
        FoldableEventKind.deviceClosed,
        FoldableEventKind.deviceOpened,
        FoldableEventKind.hingeUnavailable,
      ]),
    );
    expect(device.state.status, HingeStatus.fullyOpen);
    expect(find.textContaining('fullyOpen'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    // Real stream teardown can't complete inside the fake-async zone.
    await tester.runAsync(device.dispose);
  });
}
