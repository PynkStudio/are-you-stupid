import 'package:flutter/material.dart';

import '../../services/app_services.dart';
import '../theme.dart';
import '../widgets/ays_button.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
              animation: services.settings,
              builder: (context, _) {
                final s = services.settings;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('SETTINGS', style: Ays.title(48)),
                    const SizedBox(height: 28),
                    _Toggle(
                      label: 'SOUND',
                      value: s.soundEnabled,
                      onChanged: (v) {
                        s.setSound(v);
                        if (v) services.sound.button();
                      },
                    ),
                    _Toggle(
                      label: 'VIBRATION',
                      value: s.hapticsEnabled,
                      onChanged: (v) {
                        s.setHaptics(v);
                        if (v) services.haptics.tap();
                      },
                    ),
                    _Toggle(
                      label: 'SAVAGE MODE',
                      caption: 'Let the game roast you.',
                      value: s.roastsEnabled,
                      onChanged: s.setRoasts,
                    ),
                    const Spacer(),
                    AysButton(
                      label: 'RESET STATS',
                      height: 58,
                      fontSize: 17,
                      outlined: true,
                      onTap: () => _confirmReset(context, services),
                    ),
                    const SizedBox(height: 12),
                    AysButton(
                      label: 'BACK',
                      height: 66,
                      fontSize: 24,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'OFFLINE. NO ACCOUNT. NO DATA LEAVES THIS PHONE.',
                      textAlign: TextAlign.center,
                      style: Ays.mono(10),
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

  Future<void> _confirmReset(BuildContext context, AppServices services) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Ays.surface,
        title: Text('RESET EVERYTHING?', style: Ays.label(20)),
        content: Text(
          'Best level, attempts and streaks. Gone.',
          style: Ays.label(14, color: Ays.inkDim, weight: FontWeight.w600),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('KEEP', style: Ays.label(14)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('RESET', style: Ays.label(14, color: Ays.red)),
          ),
        ],
      ),
    );
    if (ok ?? false) await services.scores.reset();
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.label,
    required this.value,
    required this.onChanged,
    this.caption,
  });

  final String label;
  final String? caption;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: Ays.surface,
            borderRadius: Ays.radiusSmall,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: Ays.label(20)),
                    if (caption != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        caption!,
                        style: Ays.label(12,
                            color: Ays.inkDim, weight: FontWeight.w600),
                      ),
                    ],
                  ],
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
                activeThumbColor: Ays.bg,
                activeTrackColor: Ays.green,
                inactiveTrackColor: Ays.surfaceHigh,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
