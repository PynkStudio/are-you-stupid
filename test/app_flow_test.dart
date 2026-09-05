import 'package:are_you_stupid/main.dart';
import 'package:are_you_stupid/services/app_services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// End-to-end through the real widget tree: menu -> run -> game over -> retry.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AppServices> boot() async {
    SharedPreferences.setMockInitialValues({});
    return AppServices.boot();
  }

  /// Advances the ticker in small steps (pumpAndSettle would never settle:
  /// the game screen animates every frame on purpose).
  Future<void> run(WidgetTester tester, Duration total) async {
    var t = Duration.zero;
    const step = Duration(milliseconds: 50);
    while (t < total) {
      await tester.pump(step);
      t += step;
    }
  }

  testWidgets('main menu shows the pitch and the play button', (tester) async {
    await tester.pumpWidget(AreYouStupidApp(services: await boot()));
    await tester.pumpAndSettle();

    expect(find.text('ARE YOU'), findsOneWidget);
    expect(find.text('STUPID?'), findsOneWidget);
    expect(find.text("ONE JOB. DON'T FUCK IT UP."), findsOneWidget);
    expect(find.text('PLAY'), findsOneWidget);
    expect(find.text('BEST SCORE'), findsOneWidget);
    expect(find.text('SETTINGS'), findsOneWidget);
  });

  testWidgets('play -> level 1 -> timeout -> game over -> retry',
      (tester) async {
    await tester.pumpWidget(AreYouStupidApp(services: await boot()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('PLAY'));
    await tester.pump();
    await run(tester, const Duration(milliseconds: 900));

    expect(find.text('LEVEL 1'), findsOneWidget);

    // Do nothing at all: every starter challenge punishes that.
    await run(tester, const Duration(seconds: 6));

    expect(find.text('TRY AGAIN'), findsOneWidget);
    expect(find.text('SHARE RESULT'), findsOneWidget);
    expect(find.text('I REACHED'), findsOneWidget);
    expect(find.text('CAN YOU BEAT ME?'), findsOneWidget);
    expect(find.text('NEW PERSONAL BEST!'), findsOneWidget);

    await tester.tap(find.text('TRY AGAIN'));
    await tester.pump();
    await run(tester, const Duration(milliseconds: 900));

    expect(find.text('LEVEL 1'), findsOneWidget);
    expect(find.text('TRY AGAIN'), findsNothing);
  });

  testWidgets('the run is recorded in the stats screen', (tester) async {
    final services = await boot();
    await tester.pumpWidget(AreYouStupidApp(services: services));
    await tester.pumpAndSettle();

    await tester.tap(find.text('PLAY'));
    await tester.pump();
    await run(tester, const Duration(seconds: 7));
    expect(find.text('TRY AGAIN'), findsOneWidget);

    await tester.tap(find.text('HOME'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('BEST SCORE'));
    await tester.pumpAndSettle();

    expect(find.text('TOTAL ATTEMPTS'), findsOneWidget);
    expect(services.scores.totalAttempts, 1);
    expect(services.scores.bestLevel, greaterThanOrEqualTo(1));
  });

  testWidgets('settings persist sound and haptics', (tester) async {
    final services = await boot();
    await tester.pumpWidget(AreYouStupidApp(services: services));
    await tester.pumpAndSettle();

    await tester.tap(find.text('SETTINGS'));
    await tester.pumpAndSettle();

    expect(services.settings.soundEnabled, isTrue);
    await tester.tap(find.text('SOUND'));
    await tester.pumpAndSettle();
    expect(services.settings.soundEnabled, isFalse);

    await tester.tap(find.text('VIBRATION'));
    await tester.pumpAndSettle();
    expect(services.settings.hapticsEnabled, isFalse);

    await tester.tap(find.byType(Switch).last);
    await tester.pumpAndSettle();
    expect(services.settings.roastsEnabled, isFalse);
  });
}
