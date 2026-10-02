/// Final standings + share ([[Multiplayer Product]] "Sharing").
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../i18n/strings.dart';
import '../../../multiplayer/engine/party_session.dart';
import '../../../multiplayer/protocol/protocol.dart';
import '../../../services/app_services.dart';
import '../../theme.dart';
import '../../widgets/ays_button.dart';
import 'mp_common.dart';

class MpResultScreen extends StatefulWidget {
  const MpResultScreen({super.key, required this.session});

  final PartySession session;

  @override
  State<MpResultScreen> createState() => _MpResultScreenState();
}

class _MpResultScreenState extends State<MpResultScreen> {
  bool _recorded = false;

  @override
  void dispose() {
    // Safety net if the screen is popped without hitting BACK TO MENU
    // (e.g. the system back gesture) — dispose() is idempotent, and
    // leaveAndExit() usually already did this.
    unawaited(widget.session.dispose());
    super.dispose();
  }

  void _recordOnce(GameEnd end, String selfId) {
    if (_recorded) return;
    _recorded = true;
    final mine = end.results.where((r) => r.playerId == selfId).firstOrNull;
    if (mine == null) return;
    AppServices.of(context).multiplayerProfile.recordMatch(
          standing: mine.standing,
          won: end.winnerId == selfId,
        );
  }

  String _nameFor(String playerId) {
    for (final p in widget.session.state.players) {
      if (p.playerId == playerId) return p.playerName;
    }
    return playerId;
  }

  @override
  Widget build(BuildContext context) {
    final services = AppServices.of(context);
    final state = widget.session.state;
    final end = state.gameEnd;
    return Scaffold(
      body: AnimatedBuilder(
        animation: services.settings,
        builder: (context, _) {
          final locale = services.settings.locale;
          String t(String key, [Map<String, String>? args]) =>
              Strings.t(locale, key, args);

          if (end == null) {
            return MpBackground(child: Center(child: Text(t('ui.mp.result.title'), style: Ays.title(36))));
          }
          _recordOnce(end, state.selfClientId);

          final winnerName = end.winnerId != null ? _nameFor(end.winnerId!) : '';
          final sorted = [...end.results]..sort((a, b) => a.standing.compareTo(b.standing));
          final mine = end.results.where((r) => r.playerId == state.selfClientId).firstOrNull;

          return MpBackground(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                Text(t('ui.mp.result.title'), style: Ays.title(36), textAlign: TextAlign.center),
                if (winnerName.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    t('ui.mp.result.winner', {'name': winnerName.toUpperCase()}),
                    textAlign: TextAlign.center,
                    style: Ays.label(18, color: Ays.warning),
                  ),
                ],
                if (mine != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    t('ui.mp.result.your_standing', {'n': '${mine.standing}'}),
                    textAlign: TextAlign.center,
                    style: Ays.mono(13),
                  ),
                ],
                const SizedBox(height: 20),
                Expanded(
                  child: ListView.separated(
                    itemCount: sorted.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final r = sorted[i];
                      final isSelf = r.playerId == state.selfClientId;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Ays.surface,
                          borderRadius: Ays.radiusSmall,
                          border: isSelf ? Border.all(color: Ays.surfaceHigh, width: 2) : null,
                        ),
                        child: Row(
                          children: [
                            Text('#${r.standing}', style: Ays.mono(14)),
                            const SizedBox(width: 10),
                            MpAvatar(seed: r.playerId, name: _nameFor(r.playerId)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _nameFor(r.playerId).toUpperCase(),
                                style: Ays.label(16),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text('${r.score}', style: Ays.mono(14)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
                AysButton(
                  label: t('ui.mp.result.share'),
                  height: 66,
                  fontSize: 22,
                  outlined: true,
                  onTap: () => services.share.shareMultiplayerResult(winnerName, locale: locale),
                ),
                const SizedBox(height: 12),
                AysButton(
                  label: t('ui.mp.result.menu'),
                  height: 66,
                  fontSize: 22,
                  onTap: () {
                    services.sound.button();
                    leaveAndExit(context, widget.session);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
