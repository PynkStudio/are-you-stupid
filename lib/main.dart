import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'services/ads/admob_ad_provider.dart';
import 'services/app_services.dart';
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

  final services = await AppServices.boot(adProvider: AdMobAdProvider());
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
        title: 'ARE YOU STUPID?',
        debugShowCheckedModeBanner: false,
        theme: Ays.theme(),
        home: const HomeScreen(),
      ),
    );
  }
}
