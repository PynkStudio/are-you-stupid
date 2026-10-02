/// Full-screen overlay for `HOST_DISCONNECTED` / transport-closed / rejected
/// states — the "match is over, return to menu" screen
/// ([[Multiplayer Client (Mobile)]] "Reconnect").
library;

import 'package:flutter/material.dart';

import '../../../i18n/app_locale.dart';
import '../../../i18n/strings.dart';
import '../../../multiplayer/engine/party_session.dart';
import '../../../multiplayer/engine/party_state.dart';
import '../../theme.dart';
import '../../widgets/ays_button.dart';
import 'mp_common.dart';

class MpDisconnectView extends StatelessWidget {
  const MpDisconnectView({
    super.key,
    required this.session,
    required this.state,
    required this.locale,
  });

  final PartySession session;
  final PartyState state;
  final AppLocale locale;

  @override
  Widget build(BuildContext context) {
    String t(String key, [Map<String, String>? args]) =>
        Strings.t(locale, key, args);

    final message = state.phase == PartyPhase.rejected
        ? t('ui.mp.disconnect.rejected', {
            'reason': state.rejected?.reason ?? '',
          })
        : t('ui.mp.disconnect.connection_lost');

    return ColoredBox(
      color: Ays.bg.withValues(alpha: 0.97),
      child: MpBackground(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              t('ui.mp.disconnect.title'),
              textAlign: TextAlign.center,
              style: Ays.title(40),
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Ays.label(16, color: Ays.inkDim),
            ),
            const SizedBox(height: 28),
            AysButton(
              label: t('ui.mp.disconnect.menu'),
              height: 66,
              fontSize: 22,
              onTap: () => leaveAndExit(context, session),
            ),
          ],
        ),
      ),
    );
  }
}
