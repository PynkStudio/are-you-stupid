import 'package:flutter/material.dart';

import '../../i18n/strings.dart';
import '../../services/app_services.dart';
import '../theme.dart';
import '../widgets/ays_button.dart';
import 'game_screen.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final services = AppServices.of(context);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: Ays.pageGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 22),
            child: AnimatedBuilder(
              animation: services.settings,
              builder: (context, _) {
                final locale = services.settings.locale;
                String t(String key, [Map<String, String>? args]) =>
                    Strings.t(locale, key, args);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Spacer(flex: 3),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(t('ui.home.title1'), style: Ays.title(74)),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        t('ui.home.title2'),
                        style: Ays.title(96).copyWith(color: Ays.red),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      t('ui.home.tagline'),
                      textAlign: TextAlign.center,
                      style: Ays.label(16, color: Ays.inkDim),
                    ),
                    const Spacer(flex: 3),
                    AnimatedBuilder(
                      animation: services.scores,
                      builder: (context, _) {
                        final best = services.scores.bestLevel;
                        return Text(
                          best > 0
                              ? t('ui.home.best', {'n': '$best'})
                              : t('ui.home.no_score'),
                          textAlign: TextAlign.center,
                          style: Ays.mono(15, color: Ays.warning),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    AysButton(
                      label: t('ui.home.play'),
                      height: 92,
                      fontSize: 38,
                      onTap: () {
                        services.sound.button();
                        services.haptics.tap();
                        Navigator.of(context).push(
                          PageRouteBuilder(
                            transitionDuration: const Duration(milliseconds: 120),
                            pageBuilder: (_, _, _) => const GameScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: AysButton(
                            label: t('ui.home.best_score_button'),
                            height: 58,
                            fontSize: 17,
                            outlined: true,
                            onTap: () {
                              services.sound.button();
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const StatsScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AysButton(
                            label: t('ui.home.settings'),
                            height: 58,
                            fontSize: 17,
                            outlined: true,
                            onTap: () {
                              services.sound.button();
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const SettingsScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      t('ui.home.footer'),
                      textAlign: TextAlign.center,
                      style: Ays.mono(11),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
