import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'i18n/strings.dart';
import 'services/ads/ad_provider.dart';
import 'services/ads/admob_ad_provider.dart';
import 'services/ads/mock_ad_provider.dart';
import 'services/app_services.dart';
import 'services/purchases/iap_purchase_provider.dart';
import 'services/purchases/mock_purchase_provider.dart';
import 'services/purchases/purchase_provider.dart';
import 'ui/screens/home_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Ays.bg,
  ));

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
  runApp(AreYouStupidApp(services: services));
}

class AreYouStupidApp extends StatelessWidget {
  const AreYouStupidApp({super.key, required this.services});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
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
