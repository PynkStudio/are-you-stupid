/// Resolves a room code on the LAN, connects, and joins with a name
/// ([[Multiplayer Client (Mobile)]] "Mobile — join").
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../ai/apple_ai_service.dart';
import '../../../ai/feature_flags.dart';
import '../../../i18n/strings.dart';
import '../../../multiplayer/ai/party_ai_director.dart';
import '../../../multiplayer/engine/party_session.dart';
import '../../../multiplayer/engine/party_state.dart';
import '../../../multiplayer/networking/lan_discovery.dart';
import '../../../multiplayer/networking/session_socket.dart';
import '../../../services/app_services.dart';
import '../../../services/local_network_permission.dart';
import '../../theme.dart';
import '../../widgets/ays_button.dart';
import 'mp_common.dart';
import 'mp_disconnect_view.dart';
import 'mp_lobby_screen.dart';
import '../../widgets/balanced_text.dart';

/// Informational only (`HELLO.appVersion`) — the host never gates on it, so
/// this isn't wired to `pubspec.yaml`'s version on purpose.
const _kAppVersion = '0.1';

enum _Stage { resolving, notFound, networkDenied, connecting, connectError, form, rejected }

class MpJoinScreen extends StatefulWidget {
  const MpJoinScreen({super.key, required this.roomCode});

  final String roomCode;

  @override
  State<MpJoinScreen> createState() => _MpJoinScreenState();
}

class _MpJoinScreenState extends State<MpJoinScreen>
    with WidgetsBindingObserver {
  _Stage _stage = _Stage.resolving;
  PartySession? _session;
  PartyAiDirector? _aiDirector;
  StreamSubscription<PartyState>? _statesSub;
  StreamSubscription<PartyEvent>? _eventsSub;
  PartyState? _lastState;
  String? _joinError;
  bool _joining = false;
  bool _navigated = false;

  final _nameController = TextEditingController();
  final _devAddressController = TextEditingController();
  bool _showDevAddress = false;

  bool _nameSeeded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _connect();
  }

  /// Back from Settings with access switched on: retry on our own instead of
  /// making the player find TRY AGAIN.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted && _stage == _Stage.networkDenied) {
      _connect();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_nameSeeded) {
      _nameSeeded = true;
      _nameController.text = AppServices.of(context).multiplayerProfile.playerName;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _statesSub?.cancel();
    _eventsSub?.cancel();
    // Only dispose here if we never handed the session off to the lobby.
    // Once navigated, `_aiDirector` (like `_session` itself) outlives this
    // widget — it isn't threaded through Lobby/Game/Result the way
    // `_session` is, but its lifetime doesn't need to be: cancelling its
    // subscription here would be wrong (the session is still live
    // downstream), and once the eventual real owner disposes `_session`,
    // the underlying broadcast stream closes and this subscription
    // completes on its own — see [[Multiplayer AI Director]] Phase 8.
    if (!_navigated) {
      unawaited(_session?.dispose());
      _aiDirector?.dispose();
    }
    _nameController.dispose();
    _devAddressController.dispose();
    super.dispose();
  }

  Future<void> _connect({String? devAddress}) async {
    setState(() {
      _stage = _Stage.resolving;
      _joinError = null;
    });

    PartyHostCandidate? candidate;
    if (devAddress != null) {
      final parts = devAddress.split(':');
      final port = parts.length == 2 ? int.tryParse(parts[1]) : null;
      if (parts.isEmpty || port == null) {
        setState(() => _stage = _Stage.notFound);
        return;
      }
      candidate = PartyHostCandidate(
        roomCode: widget.roomCode,
        hostname: parts[0],
        address: parts[0],
        port: port,
      );
    } else {
      candidate = await LanPartyDiscovery().resolveRoomCode(widget.roomCode);
    }
    if (!mounted) return;
    if (candidate == null) {
      // "Not found" is often really "not allowed to look": tell the player
      // the actual cause and how to fix it ([[Multiplayer Client (Mobile)]]
      // "Permissions").
      final network = devAddress == null
          ? await AppServices.of(context).localNetwork.status()
          : LocalNetworkStatus.unknown;
      if (!mounted) return;
      setState(() => _stage = network == LocalNetworkStatus.denied
          ? _Stage.networkDenied
          : _Stage.notFound);
      return;
    }

    setState(() => _stage = _Stage.connecting);
    try {
      final transport = await SocketPartyTransport.connect(
        candidate.address,
        candidate.port,
      );
      if (!mounted) {
        unawaited(transport.close());
        return;
      }
      final session = PartySession(
        transport: transport,
        appName: 'ARE YOU STUPID?',
        appVersion: _kAppVersion,
      );
      _session = session;
      _aiDirector = PartyAiDirector(
        session: session,
        service: AppleAiMethodChannel(),
        loadFlags: AiFeatureFlags.load,
      );
      _statesSub = session.states.listen(_onState);
      _eventsSub = session.events.listen(_onEvent);
      session.connect();
    } catch (_) {
      if (!mounted) return;
      setState(() => _stage = _Stage.connectError);
    }
  }

  void _onState(PartyState state) {
    if (!mounted) return;
    setState(() {
      _lastState = state;
      if (state.phase == PartyPhase.lobby && _stage != _Stage.form) {
        _stage = _Stage.form;
      } else if (state.phase == PartyPhase.rejected) {
        _stage = _Stage.rejected;
      }
    });
  }

  void _onEvent(PartyEvent event) {
    if (!mounted) return;
    switch (event) {
      case PartyJoinedEvent():
        _goToLobby();
      case PartyErrorEvent(:final error):
        setState(() {
          _joining = false;
          _joinError = error.detail.isNotEmpty ? error.detail : error.code;
        });
      default:
        break;
    }
  }

  void _goToLobby() {
    if (_navigated) return;
    _navigated = true;
    final session = _session!;
    final services = AppServices.of(context);
    unawaited(services.multiplayerProfile.setProfile(
      playerName: _nameController.text.trim(),
      emoji: services.multiplayerProfile.emoji,
    ));
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => MpLobbyScreen(session: session)),
    );
  }

  void _submitJoin() {
    final session = _session;
    final name = _nameController.text.trim();
    if (session == null || name.isEmpty || _joining) return;
    setState(() {
      _joining = true;
      _joinError = null;
    });
    session.joinRoom(playerName: name, emoji: AppServices.of(context).multiplayerProfile.emoji);
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
              MpBackground(child: _buildStage(t)),
              if (_lastState?.phase == PartyPhase.disconnected)
                MpDisconnectView(
                  session: _session!,
                  state: _lastState!,
                  locale: locale,
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStage(String Function(String, [Map<String, String>?]) t) {
    switch (_stage) {
      case _Stage.resolving:
      case _Stage.connecting:
        return _Centered(
          children: [
            const CircularProgressIndicator(color: Ays.ink),
            const SizedBox(height: 20),
            Text(
              t('ui.mp.join.resolving', {'code': widget.roomCode}),
              textAlign: TextAlign.center,
              style: Ays.label(16, color: Ays.inkDim),
            ),
          ],
        );

      case _Stage.networkDenied:
        return _Centered(
          children: [
            MpPermissionNotice(
              message: t('ui.mp.permission.network_denied'),
              actionLabel: t('ui.mp.permission.open_settings'),
              onAction: () {
                final services = AppServices.of(context);
                services.sound.button();
                services.localNetwork.openAppSettings();
              },
            ),
            const SizedBox(height: 16),
            AysButton(
              label: t('ui.mp.join.retry'),
              height: 60,
              fontSize: 20,
              outlined: true,
              onTap: () => _connect(),
            ),
            const SizedBox(height: 12),
            AysButton(
              label: t('ui.mp.home.back'),
              height: 56,
              fontSize: 17,
              outlined: true,
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        );

      case _Stage.notFound:
      case _Stage.connectError:
        return _Centered(
          children: [
            Text(
              t('ui.mp.join.not_found', {'code': widget.roomCode}),
              textAlign: TextAlign.center,
              style: Ays.label(18),
            ),
            const SizedBox(height: 24),
            AysButton(
              label: t('ui.mp.join.retry'),
              height: 64,
              fontSize: 22,
              onTap: () => _connect(),
            ),
            const SizedBox(height: 12),
            AysButton(
              label: t('ui.mp.home.back'),
              height: 56,
              fontSize: 17,
              outlined: true,
              onTap: () => Navigator.of(context).pop(),
            ),
            if (kDebugMode) ...[
              const SizedBox(height: 28),
              TextButton(
                onPressed: () => setState(() => _showDevAddress = !_showDevAddress),
                child: Text(t('ui.mp.join.dev_manual_address'), style: Ays.mono(12)),
              ),
              if (_showDevAddress) ...[
                const SizedBox(height: 8),
                MpTextField(
                  controller: _devAddressController,
                  hint: '192.168.1.23:7777',
                  textAlign: TextAlign.center,
                  onSubmitted: (v) => _connect(devAddress: v.trim()),
                ),
                const SizedBox(height: 10),
                AysButton(
                  label: 'CONNECT (DEV)',
                  height: 52,
                  fontSize: 16,
                  outlined: true,
                  onTap: () => _connect(devAddress: _devAddressController.text.trim()),
                ),
              ],
            ],
          ],
        );

      case _Stage.rejected:
        return _Centered(
          children: [
            Text(
              t('ui.mp.join.rejected', {
                'reason': _lastState?.rejected?.reason ?? '',
              }),
              textAlign: TextAlign.center,
              style: Ays.label(18),
            ),
            const SizedBox(height: 24),
            AysButton(
              label: t('ui.mp.home.back'),
              height: 64,
              fontSize: 22,
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        );

      case _Stage.form:
        final hostName = _lastState?.host?.hostName ?? '';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(flex: 2),
            BalancedText(t('app.title'), style: Ays.title(36)),
            const SizedBox(height: 8),
            if (hostName.isNotEmpty)
              Text(
                t('ui.mp.join.playing_on', {'host': hostName}),
                textAlign: TextAlign.center,
                style: Ays.mono(13),
              ),
            const SizedBox(height: 28),
            Text(t('ui.mp.join.name_label'), style: Ays.label(14, color: Ays.inkDim)),
            const SizedBox(height: 8),
            MpTextField(
              controller: _nameController,
              hint: t('ui.mp.join.name_hint'),
              autofocus: true,
              onSubmitted: (_) => _submitJoin(),
            ),
            if (_joinError != null) ...[
              const SizedBox(height: 12),
              Text(_joinError!, textAlign: TextAlign.center, style: Ays.mono(13, color: Ays.wrong)),
            ],
            const Spacer(flex: 3),
            AysButton(
              label: _joining ? t('ui.mp.join.waiting_host') : t('ui.mp.join.join_button'),
              height: 78,
              fontSize: 28,
              onTap: _joining ? () {} : _submitJoin,
            ),
            const SizedBox(height: 12),
            AysButton(
              label: t('ui.mp.home.back'),
              height: 56,
              fontSize: 17,
              outlined: true,
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        );
    }
  }
}

class _Centered extends StatelessWidget {
  const _Centered({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      );
}
