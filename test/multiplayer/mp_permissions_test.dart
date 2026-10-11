// The multiplayer permissions UX ([[Multiplayer Client (Mobile)]]
// "Permissions"): the primer must come before anything touches the local
// network, and a denied/revoked permission must surface with a way to fix it.
import 'package:are_you_stupid/services/app_services.dart';
import 'package:are_you_stupid/services/local_network_permission.dart';
import 'package:are_you_stupid/ui/screens/multiplayer/mp_home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeLocalNetwork implements LocalNetworkPermission {
  _FakeLocalNetwork(
    this.answer, {
    this.wifiAnswer = WifiConnectionStatus.connected,
  });

  LocalNetworkStatus answer;
  WifiConnectionStatus wifiAnswer;
  int statusCalls = 0;
  int settingsOpened = 0;

  @override
  Future<LocalNetworkStatus> status() async {
    statusCalls++;
    return answer;
  }

  @override
  Future<bool> openAppSettings() async {
    settingsOpened++;
    return true;
  }

  @override
  Future<WifiConnectionStatus> wifiStatus() async => wifiAnswer;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final navigatorKey = GlobalKey<NavigatorState>();

  Future<(AppServices, _FakeLocalNetwork)> open(
    WidgetTester tester, {
    required bool primerSeen,
    LocalNetworkStatus answer = LocalNetworkStatus.granted,
    WifiConnectionStatus wifiAnswer = WifiConnectionStatus.connected,
  }) async {
    SharedPreferences.setMockInitialValues({
      if (primerSeen) 'ays.mp.permissionsPrimerSeen': true,
    });
    final booted = await AppServices.boot();
    final fake = _FakeLocalNetwork(answer, wifiAnswer: wifiAnswer);
    final services = AppServices(
      settings: booted.settings,
      scores: booted.scores,
      multiplayerProfile: booted.multiplayerProfile,
      localNetwork: fake,
    );
    await tester.pumpWidget(
      ServicesScope(
        services: services,
        child: MaterialApp(navigatorKey: navigatorKey, home: const SizedBox()),
      ),
    );
    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const MpHomeScreen()),
    );
    await tester.pumpAndSettle();
    return (services, fake);
  }

  testWidgets('first visit shows the primer before probing the network', (
    tester,
  ) async {
    final (services, fake) = await open(tester, primerSeen: false);

    expect(find.text('QUICK THING FIRST'), findsOneWidget);
    expect(
      fake.statusCalls,
      0,
      reason: 'no local-network access before the primer',
    );

    await tester.tap(find.text('CONTINUE'));
    await tester.pumpAndSettle();

    expect(find.text('QUICK THING FIRST'), findsNothing);
    expect(services.multiplayerProfile.permissionsPrimerSeen, isTrue);
    expect(fake.statusCalls, 1);
  });

  testWidgets('NOT NOW leaves multiplayer without touching the network', (
    tester,
  ) async {
    final (services, fake) = await open(tester, primerSeen: false);

    await tester.tap(find.text('NOT NOW'));
    await tester.pumpAndSettle();

    expect(find.byType(MpHomeScreen), findsNothing);
    expect(services.multiplayerProfile.permissionsPrimerSeen, isFalse);
    expect(fake.statusCalls, 0);
  });

  testWidgets('later visits skip the primer', (tester) async {
    final (_, fake) = await open(tester, primerSeen: true);

    expect(find.text('QUICK THING FIRST'), findsNothing);
    expect(fake.statusCalls, 1);
    expect(find.text('OPEN SETTINGS'), findsNothing);
  });

  testWidgets('a denied permission shows a notice that opens Settings', (
    tester,
  ) async {
    final (_, fake) = await open(
      tester,
      primerSeen: true,
      answer: LocalNetworkStatus.denied,
    );

    expect(find.textContaining('LOCAL NETWORK ACCESS IS OFF'), findsOneWidget);
    await tester.tap(find.text('OPEN SETTINGS'));
    await tester.pump();
    expect(fake.settingsOpened, 1);

    // Back from Settings with access on: the notice goes away by itself.
    fake.answer = LocalNetworkStatus.granted;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.textContaining('LOCAL NETWORK ACCESS IS OFF'), findsNothing);
  });

  testWidgets('being off Wi-Fi is explained before an empty room search', (
    tester,
  ) async {
    await open(
      tester,
      primerSeen: true,
      wifiAnswer: WifiConnectionStatus.disconnected,
    );

    expect(find.textContaining('NO WI-FI'), findsOneWidget);
    expect(find.text('LOOKING FOR A PARTY ON THIS WI-FI…'), findsNothing);
  });
}
