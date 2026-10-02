/// "✓ JOINED … waiting for players" + roster + self ready toggle
/// ([[Multiplayer Client (Mobile)]] "Mobile — join", after-join state).
///
/// Starting the match is TV-only ([[Multiplayer Product]] "TV — lobby"): this
/// screen never shows a START GAME button, only READY.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../i18n/strings.dart';
import '../../../multiplayer/engine/party_session.dart';
import '../../../multiplayer/engine/party_state.dart';
import '../../../multiplayer/protocol/protocol.dart';
import '../../../services/app_services.dart';
import '../../theme.dart';
import '../../widgets/ays_button.dart';
import 'mp_common.dart';
import 'mp_disconnect_view.dart';
import 'mp_game_screen.dart';
import '../../widgets/balanced_text.dart';

class MpLobbyScreen extends StatefulWidget {
  const MpLobbyScreen({super.key, required this.session});

  final PartySession session;

  @override
  State<MpLobbyScreen> createState() => _MpLobbyScreenState();
}

class _MpLobbyScreenState extends State<MpLobbyScreen> {
  late PartyState _state;
  StreamSubscription<PartyState>? _statesSub;
  StreamSubscription<PartyEvent>? _eventsSub;
  bool _navigated = false;

  PartySession get _session => widget.session;

  @override
  void initState() {
    super.initState();
    _state = _session.state;
    _statesSub = _session.states.listen((s) => setState(() => _state = s));
    _eventsSub = _session.events.listen(_onEvent);
  }

  @override
  void dispose() {
    _statesSub?.cancel();
    _eventsSub?.cancel();
    if (!_navigated) unawaited(_session.dispose());
    super.dispose();
  }

  void _onEvent(PartyEvent event) {
    if (event is PartyGameStartedEvent && !_navigated) {
      _navigated = true;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => MpGameScreen(session: _session)),
      );
    }
  }

  void _toggleReady() {
    final self = _state.self;
    if (self == null) return;
    AppServices.of(context).sound.button();
    _session.setReady(!self.ready);
  }

  @override
  Widget build(BuildContext context) {
    final services = AppServices.of(context);
    return Scaffold(
      body: AnimatedBuilder(
        animation: services.settings,
        builder: (context, _) {
          final locale = services.settings.locale;
          String t(String key, [Map<String, String>? args]) =>
              Strings.t(locale, key, args);
          return Stack(
            children: [
              MpBackground(child: _buildBody(t)),
              if (_state.phase == PartyPhase.disconnected ||
                  _state.phase == PartyPhase.rejected)
                MpDisconnectView(session: _session, state: _state, locale: locale),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBody(String Function(String, [Map<String, String>?]) t) {
    final self = _state.self;
    final ready = self?.ready ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BalancedText(t('ui.mp.lobby.title'), style: Ays.title(36)),
        const SizedBox(height: 4),
        Text(
          t('ui.mp.lobby.players', {'n': '${_state.players.length}'}),
          textAlign: TextAlign.center,
          style: Ays.mono(13),
        ),
        const SizedBox(height: 18),
        Expanded(
          child: ListView.separated(
            itemCount: _state.players.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final p = _state.players[i];
              final isSelf = p.playerId == _state.selfClientId;
              return _PlayerRow(player: p, isSelf: isSelf);
            },
          ),
        ),
        const SizedBox(height: 14),
        Text(
          t('ui.mp.lobby.waiting_start'),
          textAlign: TextAlign.center,
          style: Ays.label(13, color: Ays.inkDim),
        ),
        const SizedBox(height: 14),
        AysButton(
          label: t(ready ? 'ui.mp.lobby.ready' : 'ui.mp.lobby.not_ready'),
          height: 78,
          fontSize: 28,
          color: ready ? Ays.correct : Ays.ink,
          onTap: _toggleReady,
        ),
        const SizedBox(height: 12),
        AysButton(
          label: t('ui.mp.lobby.leave'),
          height: 56,
          fontSize: 17,
          outlined: true,
          onTap: () => leaveAndExit(context, _session),
        ),
      ],
    );
  }
}

class _PlayerRow extends StatelessWidget {
  const _PlayerRow({required this.player, required this.isSelf});

  final PlayerInfo player;
  final bool isSelf;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Ays.surface,
        borderRadius: Ays.radiusSmall,
        border: isSelf ? Border.all(color: Ays.surfaceHigh, width: 2) : null,
      ),
      child: Row(
        children: [
          MpAvatar(seed: player.playerId, name: player.playerName, emoji: player.emoji),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              player.playerName.toUpperCase(),
              style: Ays.label(16),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            player.ready ? '✓' : '○',
            style: Ays.label(20, color: player.ready ? Ays.correct : Ays.inkDim),
          ),
        ],
      ),
    );
  }
}
