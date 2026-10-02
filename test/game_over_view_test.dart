import 'package:are_you_stupid/services/app_services.dart';
import 'package:are_you_stupid/ui/screens/game_over_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The Game Over card on its own: verdict headline, killed-by card, and the
/// AI-verdict swap rule (only while the input lock still holds).
void main() {
  late AppServices services;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    services = await AppServices.boot();
  });

  Widget card({String? aiVerdict, String? instruction = 'TAP RED'}) =>
      ServicesScope(
        services: services,
        child: MaterialApp(
          home: Scaffold(
            body: GameOverView(
              level: 7,
              best: 9,
              isRecord: false,
              canContinue: false,
              onRetry: () {},
              onContinue: () {},
              onQuit: () {},
              bestStreak: 4,
              failedInstruction: instruction,
              failReason: 'THAT WAS BLUE.',
              aiVerdict: aiVerdict,
            ),
          ),
        ),
      );

  testWidgets('shows the run recap: level, best, streak, killed-by',
      (tester) async {
    await tester.pumpWidget(card());
    await tester.pumpAndSettle();

    expect(find.text('LEVEL 7'), findsOneWidget);
    expect(find.text('BEST: LEVEL 9'), findsOneWidget);
    expect(find.text('🔥 STREAK 4'), findsOneWidget);
    expect(find.text('KILLED BY'), findsOneWidget);
    expect(find.text('“TAP RED”'), findsOneWidget);
    expect(find.text('THAT WAS BLUE.'), findsOneWidget);
  });

  testWidgets('no instruction → no killed-by card', (tester) async {
    await tester.pumpWidget(card(instruction: null));
    await tester.pumpAndSettle();

    expect(find.text('KILLED BY'), findsNothing);
  });

  testWidgets('an AI verdict ready at appearance is the headline',
      (tester) async {
    await tester.pumpWidget(card(aiVerdict: 'Seven levels of pure luck.'));
    await tester.pumpAndSettle();

    expect(find.text('SEVEN LEVELS OF PURE LUCK.'), findsOneWidget);
  });

  testWidgets('a verdict arriving during the input lock swaps in',
      (tester) async {
    await tester.pumpWidget(card());
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpWidget(card(aiVerdict: 'Late but fair.'));
    await tester.pumpAndSettle();

    expect(find.text('LATE BUT FAIR.'), findsOneWidget);
  });

  testWidgets('a verdict arriving after the lock never moves the headline',
      (tester) async {
    await tester.pumpWidget(card());
    await tester.pumpAndSettle(); // past the 600 ms lock
    await tester.pumpWidget(card(aiVerdict: 'Too late.'));
    await tester.pumpAndSettle();

    expect(find.text('TOO LATE.'), findsNothing);
  });
}
