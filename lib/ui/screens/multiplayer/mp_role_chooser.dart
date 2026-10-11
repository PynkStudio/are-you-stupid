import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../i18n/strings.dart';
import '../../../i18n/app_locale.dart';
import '../../../services/app_services.dart';
import '../../theme.dart';
import '../../widgets/ays_button.dart';
import '../../widgets/balanced_text.dart';
import 'mp_home_screen.dart';

const _hostModeChannel = MethodChannel('ays/host_mode');

Future<void> openMultiplayerForPlatform(BuildContext context) async {
  if (!Platform.isMacOS) {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const MpHomeScreen()));
    return;
  }

  final services = AppServices.of(context);
  final locale = services.settings.locale;
  final role = await showDialog<_MacMultiplayerRole>(
    context: context,
    builder: (_) => _MacRoleDialog(locale: locale),
  );
  if (!context.mounted || role == null) return;

  switch (role) {
    case _MacMultiplayerRole.play:
      await Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => const MpHomeScreen()));
    case _MacMultiplayerRole.host:
      await _hostModeChannel.invokeMethod<void>('openHost');
  }
}

enum _MacMultiplayerRole { play, host }

class _MacRoleDialog extends StatelessWidget {
  const _MacRoleDialog({required this.locale});

  final AppLocale locale;

  @override
  Widget build(BuildContext context) {
    String t(String key) => Strings.t(locale, key);
    return Dialog(
      backgroundColor: Ays.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Ays.warning, width: 2),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BalancedText(
                t('ui.mp.role.title'),
                maxLines: 2,
                textAlign: TextAlign.center,
                style: Ays.title(34),
              ),
              const SizedBox(height: 12),
              Text(
                t('ui.mp.role.subtitle'),
                textAlign: TextAlign.center,
                style: Ays.mono(15, color: Ays.inkDim),
              ),
              const SizedBox(height: 24),
              AysButton(
                label: t('ui.mp.role.play'),
                height: 64,
                fontSize: 22,
                onTap: () => Navigator.pop(context, _MacMultiplayerRole.play),
              ),
              const SizedBox(height: 12),
              AysButton(
                label: t('ui.mp.role.host'),
                height: 64,
                fontSize: 22,
                outlined: true,
                onTap: () => Navigator.pop(context, _MacMultiplayerRole.host),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
