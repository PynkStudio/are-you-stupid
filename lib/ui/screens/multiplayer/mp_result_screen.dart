/// Final standings + share ([[Multiplayer Product]] "Sharing").
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../i18n/strings.dart';
import '../../../multiplayer/engine/party_session.dart';
import '../../../multiplayer/engine/party_state.dart';
import '../../../multiplayer/protocol/protocol.dart';
import '../../../services/app_services.dart';
import '../../../services/purchases/purchase_manager.dart';
import '../../theme.dart';
import '../../widgets/ays_button.dart';
import 'mp_common.dart';
import 'mp_lobby_screen.dart';
import '../../widgets/balanced_text.dart';

class MpResultScreen extends StatefulWidget {
  const MpResultScreen({super.key, required this.session});

  final PartySession session;

  @override
  State<MpResultScreen> createState() => _MpResultScreenState();
}

class _MpResultScreenState extends State<MpResultScreen> {
  bool _recorded = false;
  bool _navigated = false;
  bool _requestingRematch = false;
  StreamSubscription<PartyState>? _statesSub;
  StreamSubscription<PartyEvent>? _eventsSub;
  PurchaseManager? _purchases;

  @override
  void initState() {
    super.initState();
    _statesSub = widget.session.states.listen((_) {
      if (mounted) setState(() {});
    });
    _eventsSub = widget.session.events.listen(_onEvent);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final purchases = AppServices.of(context).purchases;
    if (!identical(_purchases, purchases)) {
      _purchases?.removeListener(_onPurchaseChanged);
      _purchases = purchases;
      purchases.addListener(_onPurchaseChanged);
    }
  }

  @override
  void dispose() {
    // Safety net if the screen is popped without hitting BACK TO MENU
    // (e.g. the system back gesture) — dispose() is idempotent, and
    // leaveAndExit() usually already did this.
    _statesSub?.cancel();
    _eventsSub?.cancel();
    _purchases?.removeListener(_onPurchaseChanged);
    if (!_navigated) unawaited(widget.session.dispose());
    super.dispose();
  }

  void _onPurchaseChanged() {
    if (!mounted) return;
    final services = AppServices.of(context);
    if (services.settings.adsRemoved) {
      widget.session.updateRoomEntitlements(
        noAds: true,
        partyPack: services.settings.partyCapacityUnlocked,
      );
    }
    setState(() {});
  }

  Future<void> _onEvent(PartyEvent event) async {
    if (!mounted) return;
    if (event is PartyAdBreakStartedEvent &&
        event.adBreak.playerId == widget.session.state.selfClientId) {
      await AppServices.of(context).ads
          .showMultiplayerRematchInterstitial(context);
      if (mounted) widget.session.finishAdBreak();
    } else if (event is PartyRematchReadyEvent && !_navigated) {
      _navigated = true;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => MpLobbyScreen(session: widget.session),
        ),
      );
    }
  }

  void _requestRematch() {
    if (_requestingRematch || widget.session.state.adBreakPlayerId != null) {
      return;
    }
    setState(() => _requestingRematch = true);
    AppServices.of(context).sound.button();
    widget.session.requestRematch();
  }

  void _recordOnce(GameEnd end, String selfId) {
    if (_recorded) return;
    _recorded = true;
    final mine = end.results.where((r) => r.playerId == selfId).firstOrNull;
    if (mine == null) return;
    AppServices.of(context).multiplayerProfile
        .recordMatch(standing: mine.standing, won: end.winnerId == selfId);
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
            return MpBackground(
              child: Center(
                child: BalancedText(
                  t('ui.mp.result.title'),
                  style: Ays.title(36),
                ),
              ),
            );
          }
          _recordOnce(end, state.selfClientId);

          final sorted = [...end.results]
            ..sort((a, b) => a.standing.compareTo(b.standing));
          // A Battle with a shared top score ends without a winner and
          // with every leader on standing 1: a draw, not a win by join order.
          final tied = end.mode == GameMode.stupidBattle && end.winnerId == null
              ? [
                  for (final r in sorted)
                    if (r.standing == 1) _nameFor(r.playerId).toUpperCase(),
                ]
              : const <String>[];
          final isTie = tied.length > 1;
          final winnerName = end.winnerId != null
              ? _nameFor(end.winnerId!)
              : isTie
              ? tied.join(' & ')
              : '';
          final isLss = end.mode == GameMode.lastStupidStanding;
          final mine = end.results
              .where((r) => r.playerId == state.selfClientId)
              .firstOrNull;
          final adBreakPlayer = state.adBreakPlayerId;
          final isMyAd = adBreakPlayer == state.selfClientId;
          final adBreakName = adBreakPlayer == null
              ? ''
              : _nameFor(adBreakPlayer);

          return MpBackground(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                BalancedText(t('ui.mp.result.title'), style: Ays.title(36)),
                if (isTie) ...[
                  const SizedBox(height: 6),
                  Text(
                    t('ui.mp.result.tie'),
                    textAlign: TextAlign.center,
                    style: Ays.label(18, color: Ays.warning),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    winnerName,
                    textAlign: TextAlign.center,
                    style: Ays.label(14),
                  ),
                ] else if (winnerName.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    t('ui.mp.result.winner', {
                      'name': winnerName.toUpperCase(),
                    }),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Ays.surface,
                          borderRadius: Ays.radiusSmall,
                          border: isSelf
                              ? Border.all(color: Ays.surfaceHigh, width: 2)
                              : null,
                        ),
                        child: Row(
                          children: [
                            Text('#${r.standing}', style: Ays.mono(14)),
                            const SizedBox(width: 10),
                            MpAvatar(
                              seed: r.playerId,
                              name: _nameFor(r.playerId),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _nameFor(r.playerId).toUpperCase(),
                                style: Ays.label(16),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // LSS has no points: its score is the round
                            // the player reached before going out.
                            Text(
                              isLss
                                  ? t('ui.game.level', {'n': '${r.score}'})
                                  : '${r.score}',
                              style: Ays.mono(14),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
                if (adBreakPlayer != null) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Ays.pink,
                      borderRadius: Ays.radiusSmall,
                    ),
                    child: Column(
                      children: [
                        Text(
                          t(
                            isMyAd
                                ? 'ui.mp.adbreak.mine'
                                : 'ui.mp.adbreak.other',
                            {'name': adBreakName.toUpperCase()},
                          ),
                          textAlign: TextAlign.center,
                          style: Ays.title(18),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          t('ui.mp.adbreak.troll'),
                          textAlign: TextAlign.center,
                          style: Ays.label(12),
                        ),
                      ],
                    ),
                  ),
                  if (!isMyAd &&
                      !services.settings.adsRemoved &&
                      services.purchases.product != null) ...[
                    const SizedBox(height: 10),
                    AysButton(
                      label: t('ui.mp.adbreak.buy_no_ads', {
                        'price': services.purchases.product!.price,
                      }),
                      height: 54,
                      fontSize: 16,
                      outlined: true,
                      onTap: () {
                        if (!services.purchases.busy) {
                          services.purchases.buyRemoveAds();
                        }
                      },
                    ),
                  ],
                  const SizedBox(height: 12),
                ] else ...[
                  AysButton(
                    label: t('ui.mp.result.rematch'),
                    height: 66,
                    fontSize: 22,
                    onTap: () {
                      if (!_requestingRematch) _requestRematch();
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                AysButton(
                  label: t('ui.mp.result.share'),
                  height: 66,
                  fontSize: 22,
                  outlined: true,
                  onTap: () => services.share.shareMultiplayerResult(
                    winnerName,
                    locale: locale,
                  ),
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
