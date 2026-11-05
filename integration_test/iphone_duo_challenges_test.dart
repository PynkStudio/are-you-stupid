// Plays the five foldable challenges against the REAL hinge on an iPhone Duo
// simulator. Someone has to move the hinge in Device Hub while it runs: each
// round prints what it needs, and start the device Closed.
//
//   flutter test integration_test/iphone_duo_challenges_test.dart -d <device>
//
// There is no engine here, so rounds can't time out while you reach for the
// button. The timing rules are covered in test/foldable/.
import 'dart:math';

import 'package:are_you_stupid/challenges/foldable_challenges.dart';
import 'package:are_you_stupid/core/challenge.dart';
import 'package:are_you_stupid/core/foldable.dart';
import 'package:are_you_stupid/services/foldable_bridge.dart';
import 'package:are_you_stupid/ui/theme.dart';
import 'package:are_you_stupid/ui/widgets/challenge_renderer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

class _Host implements ChallengeHost {
  bool passed = false;
  String? failReason;
  bool get settled => passed || failReason != null;

  @override
  void pass({String? note}) => passed = true;

  @override
  void fail({String? reason}) => failReason ??= reason ?? 'failed';

  @override
  void invalidate() {}
}

ChallengeParams _params(int seed) =>
    ChallengeParams(level: 10, rng: Random(seed), speed: 1);

/// A safe the Partially Open pose (about 129°) can open.
int _safeSeedFromFlat(FoldableState flat) {
  for (var seed = 0; ; seed++) {
    final c = CrackTheCodeChallenge(_params(seed));
    c.onDeviceEvent(
      FoldableEvent(
        FoldableEventKind.initialState,
        previous: flat,
        current: flat,
      ),
      _Host(),
    );
    if ((c.targetAngle! - 129).abs() <= 5) return seed;
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the five challenges follow the real hinge', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox.expand()));
    final device = FoldableDeviceController(hinge: PlatformHingeProvider());

    Future<void> idle() =>
        Future<void>.delayed(const Duration(milliseconds: 100));

    Future<void> waitFor(HingeStatus status, String prompt) async {
      debugPrint('[need] $prompt');
      for (var i = 0; i < 900 && device.state.status != status; i++) {
        await tester.runAsync(idle);
      }
      expect(device.state.status, status, reason: prompt);
      // Let the pose settle: the hinge keeps moving after the status flips.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 3)),
      );
    }

    Future<_Host> play(
      Challenge challenge,
      String prompt, {
      void Function(_Host host)? whenReady,
      bool Function()? ready,
    }) async {
      final host = _Host();
      final start = device.state;
      challenge.onStart(host);
      challenge.onDeviceEvent(
        FoldableEvent(
          FoldableEventKind.initialState,
          previous: start,
          current: start,
        ),
        host,
      );
      final sub = device.events.listen((e) {
        debugPrint('[event] ${challenge.id} $e');
        challenge.onDeviceEvent(e, host);
      });
      debugPrint('[round] ${challenge.id} from $start — $prompt');
      var elapsed = Duration.zero;
      for (var i = 0; i < 900 && !host.settled; i++) {
        await tester.pumpWidget(
          MaterialApp(
            theme: Ays.theme(),
            home: Scaffold(
              body: SafeArea(
                child: ChallengeRenderer(
                  view: challenge.view,
                  claim: TapClaim(),
                  onTarget: (_, _, _) {},
                ),
              ),
            ),
          ),
        );
        await tester.runAsync(idle);
        elapsed += const Duration(milliseconds: 100);
        challenge.onTick(elapsed, host);
        if (whenReady != null && (ready?.call() ?? false)) {
          whenReady(host);
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(seconds: 2)),
          );
          whenReady = null;
        }
      }
      await tester.runAsync(sub.cancel);
      debugPrint(
        '[result] ${challenge.id} '
        '${host.passed ? 'PASSED' : 'FAILED: ${host.failReason}'} '
        'after ${elapsed.inMilliseconds} ms at ${device.state}',
      );
      return host;
    }

    await waitFor(HingeStatus.closed, 'Closed');
    final open = await play(DontOpenChallenge(_params(1)), 'press Open');
    expect(open.failReason, isNotNull, reason: 'opening must fail DO NOT OPEN');

    await waitFor(HingeStatus.fullyOpen, 'Open');
    final side = OtherSideChallenge(_params(2));
    final sideHost = await play(
      side,
      'press Closed',
      ready: () => side.revealed,
      whenReady: (h) => side.onTap(
        TapInfo(targetId: 'd${side.missing}', elapsed: Duration.zero),
        h,
      ),
    );
    expect(sideHost.passed, isTrue, reason: 'THE OTHER SIDE');

    await waitFor(HingeStatus.closed, 'Closed');
    final bend = await play(
      BendOverChallenge(_params(3)),
      'press Partially Open',
    );
    expect(bend.passed, isTrue, reason: 'BEND OVER');

    await waitFor(HingeStatus.partiallyOpen, 'Partially Open');
    final mind = OpenYourMindChallenge(_params(4));
    final mindHost = await play(
      mind,
      'nothing to press',
      ready: () => device.state.status == HingeStatus.partiallyOpen,
      whenReady: (h) => mind.onTap(
        TapInfo(targetId: mind.answer.name, elapsed: Duration.zero),
        h,
      ),
    );
    expect(mindHost.passed, isTrue, reason: 'OPEN YOUR MIND');

    await waitFor(HingeStatus.fullyOpen, 'Open');
    final safe = CrackTheCodeChallenge(
      _params(_safeSeedFromFlat(device.state)),
    );
    final safeHost = await play(safe, 'press Partially Open');
    expect(safeHost.passed, isTrue, reason: 'CRACK THE CODE');

    await tester.runAsync(device.dispose);
  });
}
