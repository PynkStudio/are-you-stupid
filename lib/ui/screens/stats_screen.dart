import 'package:flutter/material.dart';

import '../../i18n/strings.dart';
import '../../services/app_services.dart';
import '../theme.dart';
import '../widgets/ays_button.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final services = AppServices.of(context);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: Ays.pageGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 22),
            child: AnimatedBuilder(
              animation: Listenable.merge([services.scores, services.settings]),
              builder: (context, _) {
                final s = services.scores;
                final locale = services.settings.locale;
                String t(String key, [Map<String, String>? args]) =>
                    Strings.t(locale, key, args);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(t('ui.stats.title'), style: Ays.title(44)),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 26),
                      decoration: BoxDecoration(
                        color: Ays.surface,
                        borderRadius: Ays.radius,
                      ),
                      child: Column(
                        children: [
                          Text(t('ui.stats.level'), style: Ays.mono(14)),
                          Text('${s.bestLevel}', style: Ays.title(86)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _Row(
                      label: t('ui.stats.total_attempts'),
                      value: '${s.totalAttempts}',
                    ),
                    _Row(
                      label: t('ui.stats.average_level'),
                      value: s.averageLevel.toStringAsFixed(1),
                    ),
                    _Row(
                      label: t('ui.stats.highest_streak'),
                      value: '${s.bestStreak}',
                    ),
                    const Spacer(),
                    AysButton(
                      label: t('ui.stats.back'),
                      height: 66,
                      fontSize: 24,
                      onTap: () => Navigator.of(context).pop(),
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

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Ays.label(15, color: Ays.inkDim)),
          Text(value, style: Ays.label(22)),
        ],
      ),
    );
  }
}
