// The app has to fill iPhone Duo's displays in any orientation. Sizes measured
// on the Xcode 27.2 simulator (see iphone_duo_layout_test.dart for the rounds).
import 'package:are_you_stupid/main.dart';
import 'package:are_you_stupid/services/app_services.dart';
import 'package:are_you_stupid/ui/screens/game_over_view.dart';
import 'package:are_you_stupid/ui/screens/settings_screen.dart';
import 'package:are_you_stupid/ui/screens/stats_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _sizes = {
  'cover': Size(466, 678),
  'inner landscape': Size(951, 669),
  'inner upright': Size(669, 951),
  'inner split view': Size(334, 951),
};

void main() {
  for (final entry in _sizes.entries) {
    testWidgets('Home, Settings, Stats and Game Over fit ${entry.key}', (
      tester,
    ) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final services = await AppServices.boot();
      await tester.pumpWidget(AreYouStupidApp(services: services));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull, reason: 'Home');
      expect(find.text('PLAY'), findsOneWidget);

      final context = tester.element(find.text('PLAY'));
      for (final screen in <Widget>[
        const SettingsScreen(),
        const StatsScreen(),
        GameOverView(
          level: 12,
          best: 20,
          isRecord: false,
          bestStreak: 4,
          failedInstruction: 'THE ANSWER IS ON THE OTHER SIDE.',
          failReason: "YOU'VE GOT TWO SIDES AND SOMEHOW CHOSE NEITHER.",
          canContinue: true,
          onRetry: () {},
          onContinue: () {},
          onQuit: () {},
        ),
      ]) {
        Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => Scaffold(body: screen)));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull, reason: '$screen');
        Navigator.of(context).pop();
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
      }
    });
  }
}
