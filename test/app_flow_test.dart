import 'package:are_you_stupid/ai/apple_ai_service.dart';
import 'package:are_you_stupid/main.dart';
import 'package:are_you_stupid/services/app_services.dart';
import 'package:are_you_stupid/ui/widgets/timer_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

/// Records every URL handed to `url_launcher` instead of touching a real
/// browser, so the settings-links test can run headless.
class _FakeUrlLauncher extends UrlLauncherPlatform {
  final launched = <String>[];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched.add(url);
    return true;
  }
}

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

    // Do nothing at all: every starter challenge punishes that. Long enough
    // to clear the slowest starter's timeout at level 1's speed plus the
    // full (skippable) wrong flash — see GameEngine.wrongFlash.
    await run(tester, const Duration(seconds: 9));

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

    // Regression guard: the timer bar must come back after a retry, not
    // stay hidden from wherever the previous run left it (e.g. level 6+).
    expect(tester.widget<TimerBar>(find.byType(TimerBar)).visible, isTrue);
    final fill = find.descendant(
      of: find.byType(TimerBar),
      matching: find.byType(DecoratedBox),
    );
    expect(tester.getSize(fill).height, 8);
    expect(tester.getSize(fill).width, greaterThan(0));
  });

  testWidgets('level 1 shows the timer bar and no pace note yet',
      (tester) async {
    await tester.pumpWidget(AreYouStupidApp(services: await boot()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('PLAY'));
    await tester.pump();
    await run(tester, const Duration(milliseconds: 900));

    expect(find.text('LEVEL 1'), findsOneWidget);
    expect(tester.widget<TimerBar>(find.byType(TimerBar)).visible, isTrue);
    expect(find.text('FASTER NOW.'), findsNothing);
    expect(find.text('NO MORE TIMER.'), findsNothing);

    // Regression guard: an earlier Row/Expanded-based fill laid out at zero
    // height on a real device despite `visible` being true — see
    // docs/Meta/Decision Log.md. The current Container-based fill is sized
    // in real pixels, so this pins both dimensions directly.
    final fill = find.descendant(
      of: find.byType(TimerBar),
      matching: find.byType(DecoratedBox),
    );
    expect(tester.getSize(fill).height, 8);
    expect(tester.getSize(fill).width, greaterThan(0));
  });

  testWidgets('tapping the wrong flash skips it early', (tester) async {
    await tester.pumpWidget(AreYouStupidApp(services: await boot()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('PLAY'));
    await tester.pump();
    await run(tester, const Duration(milliseconds: 900));
    expect(find.text('LEVEL 1'), findsOneWidget);

    // Let the starter challenge time out into the wrong flash, but stop
    // comfortably before GameEngine.wrongFlash would resolve it on its own
    // (every starter's level-1 timeout lands well under this).
    await run(tester, const Duration(milliseconds: 5000));
    expect(find.text('TAP TO SKIP.'), findsOneWidget);
    expect(find.text('TRY AGAIN'), findsNothing);

    await tester.tap(find.text('TAP TO SKIP.'));
    await tester.pump();

    expect(find.text('TRY AGAIN'), findsOneWidget);
  });

  testWidgets('the run is recorded in the stats screen', (tester) async {
    final services = await boot();
    await tester.pumpWidget(AreYouStupidApp(services: services));
    await tester.pumpAndSettle();

    await tester.tap(find.text('PLAY'));
    await tester.pump();
    await run(tester, const Duration(seconds: 9));
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

  testWidgets('the Ai section shows a mode picker defaulting to Genius', (tester) async {
    final services = await boot();
    await tester.pumpWidget(AreYouStupidApp(services: services));
    await tester.pumpAndSettle();

    // `_AiSection` calls the real `ays/apple_intelligence` MethodChannel
    // (`AppleAiMethodChannel().available()`). With no mock handler
    // installed at all, `invokeMethod` never resolves in this widget-test
    // binding (unlike a bare `test()`, where an unregistered channel
    // rejects with `MissingPluginException` right away — see
    // apple_ai_service_test.dart) — it just hangs, so `_AiSection` never
    // reaches its `setState()` and the whole test would time out. A real
    // app never has this problem (there either is a native handler, iOS,
    // or the plugin registration itself throws `MissingPluginException`
    // cleanly, Android/other platforms); this mock only stands in for the
    // "device can't run the model" response a real environment would give.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel(kAppleIntelligenceChannel),
      (call) async => call.method == 'available'
          ? {'state': 'unavailable', 'reason': 'bridgeUnavailable'}
          : null,
    );
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel(kAppleIntelligenceChannel),
        null,
      );
    });

    await tester.tap(find.text('SETTINGS'));
    await tester.pumpAndSettle();

    expect(find.text('AI CHALLENGES'), findsOneWidget);
    expect(find.text('GENIUS'), findsOneWidget);
    // No native bridge in a widget test (MissingPluginException, handled
    // gracefully — see apple_ai_service.dart) — the device genuinely can't
    // run the model here, so the picker is disabled and the copy says so.
    expect(find.text('Not supported on this device.'), findsOneWidget);
  });

  testWidgets('buying remove-ads flips the row to owned and persists',
      (tester) async {
    final services = await boot();
    await tester.pumpWidget(AreYouStupidApp(services: services));
    await tester.pumpAndSettle();

    await tester.tap(find.text('SETTINGS'));
    await tester.pumpAndSettle();

    expect(services.settings.noAdsPurchased, isFalse);
    expect(find.text('REMOVE ADS'), findsOneWidget);

    // The row sits at the bottom of the settings list, below the fold.
    await tester.ensureVisible(find.text('REMOVE ADS'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('REMOVE ADS'));
    await tester.pumpAndSettle();

    expect(services.settings.noAdsPurchased, isTrue);
    // Matches both the settings row and the confirmation SnackBar.
    expect(find.text('ADS REMOVED'), findsWidgets);
    expect(find.text('REMOVE ADS'), findsNothing);
    // Once owned, the ad-suppression this purchase actually buys kicks in
    // immediately, offline included.
    expect(services.ads.isRewardedContinueReady, isTrue);
    expect(services.ads.shouldShowInterstitial, isFalse);
  });

  testWidgets(
      'about/privacy rows and the PynkStudio credit open the right URLs (English)',
      (tester) async {
    final fake = _FakeUrlLauncher();
    final original = UrlLauncherPlatform.instance;
    UrlLauncherPlatform.instance = fake;
    addTearDown(() => UrlLauncherPlatform.instance = original);

    SharedPreferences.setMockInitialValues({'ays.locale': 'en'});
    await tester.pumpWidget(AreYouStupidApp(services: await AppServices.boot()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('SETTINGS'));
    await tester.pumpAndSettle();

    // Same "below the fold" situation as REMOVE ADS above: these two rows
    // plus the "Made by PynkStudio" credit push the settings list past one
    // screen's height on common devices, so they need ensureVisible before
    // tapping.
    await tester.ensureVisible(find.text('ABOUT THE GAME'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ABOUT THE GAME'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('PRIVACY POLICY'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PRIVACY POLICY'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Made by PynkStudio'));
    await tester.pumpAndSettle();

    // Every non-Italian locale gets the English case-study page.
    expect(fake.launched, [
      'https://pynkstudio.eu/it/lavori/are-you-stupid/en',
      'https://pynkstudio.eu/it/lavori/are-you-stupid/privacy',
      'https://pynkstudio.eu',
    ]);
  });

  testWidgets('the about row links to the Italian case-study page in Italian',
      (tester) async {
    final fake = _FakeUrlLauncher();
    final original = UrlLauncherPlatform.instance;
    UrlLauncherPlatform.instance = fake;
    addTearDown(() => UrlLauncherPlatform.instance = original);

    SharedPreferences.setMockInitialValues({'ays.locale': 'it'});
    await tester.pumpWidget(AreYouStupidApp(services: await AppServices.boot()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('IMPOSTAZIONI'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('INFO SUL GIOCO'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('INFO SUL GIOCO'));
    await tester.pumpAndSettle();

    expect(fake.launched, ['https://pynkstudio.eu/it/lavori/are-you-stupid']);
  });
}
