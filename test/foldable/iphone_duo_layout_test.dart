// Every round must fit the sizes the iPhone Duo really gives us. Measured on
// the Xcode 27.2 simulator: 466x678 closed. The inner display's screen is
// 669x951, and it ignores our portrait lock, so landscape and a half-width
// Split View have to work too.
import 'dart:math';

import 'package:are_you_stupid/challenges/foldable_challenges.dart';
import 'package:are_you_stupid/challenges/registry.dart';
import 'package:are_you_stupid/core/challenge.dart';
import 'package:are_you_stupid/core/foldable.dart';
import 'package:are_you_stupid/ui/theme.dart';
import 'package:are_you_stupid/ui/widgets/challenge_renderer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_host.dart';

const _sizes = {
  'cover': Size(466, 678),
  'inner': Size(669, 951),
  'inner landscape': Size(951, 669),
  'inner upright': Size(669, 951),
  'inner split view': Size(334, 951),
};

void main() {
  for (final entry in _sizes.entries) {
    testWidgets('every round fits ${entry.key}', (tester) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final templates = [
        ...kChallengeTemplates,
        ...kFoldableChallengeTemplates,
      ];
      for (final template in templates) {
        final challenge = template.build(
          ChallengeParams(level: 20, rng: Random(3), speed: 1),
        );
        final host = FakeHost();
        const half = FoldableState(
          status: HingeStatus.partiallyOpen,
          angleDegrees: 90,
          display: DisplayConfiguration.expanded,
        );
        challenge.onStart(host);
        challenge.onDeviceEvent(
          const FoldableEvent(
            FoldableEventKind.initialState,
            previous: half,
            current: half,
          ),
          host,
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: Ays.theme(),
            home: Scaffold(
              body: ChallengeRenderer(
                view: challenge.view,
                claim: TapClaim(),
                onTarget: (_, _, _) {},
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 500));
        expect(tester.takeException(), isNull, reason: template.id);
      }
      await tester.pumpWidget(const SizedBox());
    });
  }
}
