import 'package:are_you_stupid/ui/widgets/timer_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards two independent scares from the same real-device report:
/// 1. `TimerBar`'s fill used to be a childless `DecoratedBox` sized only by
///    `Expanded`'s flex, which laid out at zero height without
///    `crossAxisAlignment: stretch` on its `Row` — invisible on a real
///    device despite `visible` being true. Fixed, then replaced entirely
///    with a `Container` given explicit pixel width/height via
///    `LayoutBuilder`, which can't fall into that trap on any rendering
///    backend. See docs/Meta/Decision Log.md.
/// 2. Whether the bar can get stuck hidden across a Game Over -> RETRY
///    cycle, which tears the whole `Column` (`TimerBar` included) out of
///    the tree during `GamePhase.intro` and mounts a fresh one — this file
///    isolates exactly that destroy/remount lifecycle without the rest of
///    the app.
void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  double currentOpacity(WidgetTester tester) {
    final renderObject = tester
        .renderObject<RenderAnimatedOpacity>(find.byType(AnimatedOpacity));
    return renderObject.opacity.value;
  }

  testWidgets('a freshly remounted TimerBar shows at full opacity immediately',
      (tester) async {
    // Level 6+: hidden.
    await tester.pumpWidget(wrap(const TimerBar(progress: 0.2, visible: false)));
    await tester.pump(const Duration(milliseconds: 200));
    expect(currentOpacity(tester), 0.0);

    // Game Over -> RETRY -> GamePhase.intro: the whole Column (TimerBar
    // included) is torn out of the tree, replaced by the "READY?" text.
    await tester.pumpWidget(wrap(const Text('READY?')));
    await tester.pump();
    expect(find.byType(TimerBar), findsNothing);

    // New run, level 1: a brand new TimerBar mounts with visible: true.
    await tester.pumpWidget(wrap(const TimerBar(progress: 0, visible: true)));
    await tester.pump();

    expect(currentOpacity(tester), 1.0);
  });
}
