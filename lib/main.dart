import 'dart:io' show Platform;

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

  @override
  void initState() {
    super.initState();
    _services = widget.services;
    if (_services == null) {
      _boot();
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
    // After the first frame of the real UI, so the consent form and the ATT
    // prompt are shown over an active app (iOS drops ATT requests made
    // while the app is still launching).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) services.startAds().catchError((Object _) {});
    });
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
        title: Strings.t(services.settings.locale, 'app.title'),
        debugShowCheckedModeBanner: false,
        theme: Ays.theme(),
        home: const HomeScreen(),
      ),
    );
  }
}
