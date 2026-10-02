import 'dart:async';
import 'dart:io' show Platform;

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ai/feature_flags.dart';
import 'i18n/strings.dart';
import 'services/ads/ad_provider.dart';
import 'services/ads/admob_ad_provider.dart';
import 'services/ads/mock_ad_provider.dart';
import 'services/app_services.dart';
import 'services/purchases/iap_purchase_provider.dart';
import 'services/purchases/mock_purchase_provider.dart';
import 'services/purchases/purchase_provider.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/multiplayer/mp_common.dart';
import 'ui/screens/multiplayer/mp_home_screen.dart';
import 'ui/screens/multiplayer/mp_join_screen.dart';
import 'ui/screens/splash_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The on-device AI director is Apple Intelligence only. Android phones
  // never generate, but still play AI rounds an iOS Director relays in
  // multiplayer — see [AiFeatureFlags.platformSupported].
  AiFeatureFlags.platformSupported = Platform.isIOS;
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Ays.bg,
  ));

  // runApp fires immediately so the first frame is the animated splash, not
  // a blank/white one — AppServices.boot() (ads SDK, purchases, prefs) used
  // to be awaited before runApp, which left the OS launch screen up for as
  // long as that took. See AreYouStupidApp._boot.
  runApp(const AreYouStupidApp());
}

class AreYouStupidApp extends StatefulWidget {
  const AreYouStupidApp({super.key, this.services});

  /// Pre-booted services. Tests pass this so the real UI renders on the
  /// very first frame, with no splash. Left null in production: main()
  /// mounts this widget before [AppServices.boot] resolves, so
  /// [SplashScreen] has something to animate instead of a blank frame.
  final AppServices? services;

  @override
  State<AreYouStupidApp> createState() => _AreYouStupidAppState();
}

class _AreYouStupidAppState extends State<AreYouStupidApp> {
  AppServices? _services;
  final _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<Uri>? _appLinksSubscription;
  String? _pendingRoomCode;
  bool _openingDeepLink = false;
  String? _lastAppLink;
  DateTime? _lastAppLinkAt;

  @override
  void initState() {
    super.initState();
    _services = widget.services;
    if (Platform.isAndroid || Platform.isIOS) {
      _listenForAppLinks();
    }
    if (_services == null) {
      _boot();
    } else {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _openPendingDeepLink(),
      );
    }
  }

  Future<void> _listenForAppLinks() async {
    final appLinks = AppLinks();
    _appLinksSubscription = appLinks.uriLinkStream.listen(
      _receiveAppLink,
      onError: (Object _) {},
    );
    try {
      final initialLink = await appLinks.getInitialLink();
      if (initialLink != null) _receiveAppLink(initialLink);
    } on Object {
      // A malformed or unavailable platform link must never block app boot.
    }
  }

  void _receiveAppLink(Uri uri) {
    final now = DateTime.now();
    if (_lastAppLink == uri.toString() &&
        _lastAppLinkAt != null &&
        now.difference(_lastAppLinkAt!) < const Duration(seconds: 2)) {
      return;
    }
    _lastAppLink = uri.toString();
    _lastAppLinkAt = now;
    final roomCode = roomCodeFromScannedValue(uri.toString());
    if (roomCode == null) return;
    _pendingRoomCode = roomCode;
    _openPendingDeepLink();
  }

  Future<void> _openPendingDeepLink() async {
    if (_openingDeepLink || _services == null || _pendingRoomCode == null) {
      return;
    }
    final context = _navigatorKey.currentContext;
    if (context == null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _openPendingDeepLink(),
      );
      return;
    }

    _openingDeepLink = true;
    final roomCode = _pendingRoomCode!;
    _pendingRoomCode = null;
    final services = _services!;
    final profile = services.multiplayerProfile;

    if (!profile.permissionsPrimerSeen) {
      final accepted = await showMpPermissionsPrimer(
        context,
        services.settings.locale,
      );
      if (!mounted) return;
      if (!accepted) {
        _openingDeepLink = false;
        return;
      }
      await profile.markPermissionsPrimerSeen();
      if (!mounted) return;
      // Keep the system Local Network prompt immediately after our primer,
      // just like the in-app MULTIPLAYER entry point.
      await services.localNetwork.status();
      if (!mounted) return;
    }

    await _navigatorKey.currentState?.push(
      MaterialPageRoute<void>(builder: (_) => MpJoinScreen(roomCode: roomCode)),
    );
    _openingDeepLink = false;
    if (_pendingRoomCode != null) {
      _openPendingDeepLink();
    }
  }

  Future<void> _boot() async {
    // google_mobile_ads and in_app_purchase only ship Android/iOS
    // implementations; other platforms (macOS/Windows/Linux/web dev builds)
    // fall back to the mocks so boot doesn't hang on a platform channel
    // nobody answers.
    final isMobile = Platform.isAndroid || Platform.isIOS;
    final AdProvider adProvider = isMobile ? AdMobAdProvider() : MockAdProvider();
    final PurchaseProvider purchaseProvider =
        isMobile ? IapPurchaseProvider() : MockPurchaseProvider();
    final services = await AppServices.boot(
      adProvider: adProvider,
      purchaseProvider: purchaseProvider,
    );
    if (!mounted) return;
    setState(() => _services = services);
    WidgetsBinding.instance.addPostFrameCallback((_) => _openPendingDeepLink());
    // After the first frame of the real UI, so the consent form and the ATT
    // prompt are shown over an active app (iOS drops ATT requests made
    // while the app is still launching).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) services.startAds().catchError((Object _) {});
    });
  }

  @override
  void dispose() {
    _appLinksSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final services = _services;
    // ServicesScope must wrap MaterialApp (not just `home`), or any screen
    // reached via Navigator.push — a sibling route, not a descendant of
    // `home` — can't find it via AppServices.of(context). Since it needs a
    // real AppServices, the splash gets its own minimal MaterialApp instead
    // of being a branch inside the real one.
    if (services == null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: Ays.theme(),
        home: const SplashScreen(),
      );
    }
    return ServicesScope(
      services: services,
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        title: Strings.t(services.settings.locale, 'app.title'),
        debugShowCheckedModeBanner: false,
        theme: Ays.theme(),
        home: const HomeScreen(),
      ),
    );
  }
}
