/// MULTIPLAYER entry point: scan the TV's QR or type the room code.
/// ([[Multiplayer Client (Mobile)]], [[Multiplayer Product]] "Mobile — menu
/// entry").
///
/// Also owns the permissions UX ([[Multiplayer Client (Mobile)]]
/// "Permissions"): the first visit shows a primer *before* anything touches
/// the local network, so the iOS Local Network prompt only ever appears right
/// after the app has explained it. Later visits re-check the permission and,
/// if it was denied or revoked, show a banner that deep-links to Settings.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../i18n/strings.dart';
import '../../../services/app_services.dart';
import '../../../services/local_network_permission.dart';
import '../../../multiplayer/networking/lan_discovery.dart';
import '../../theme.dart';
import '../../widgets/ays_button.dart';
import 'mp_common.dart';
import 'mp_join_screen.dart';
import '../../widgets/balanced_text.dart';

/// The QR encodes `areyoustupid://join?room=XXXX` ([[Multiplayer Protocol]]).
final _deepLinkRoomCode = RegExp(
  r'^areyoustupid://join\?room=([A-Za-z0-9]{4})$',
);

/// Extracts the room code from a scanned QR payload, or null if it isn't
/// ours. Pulled out as a pure function so it's unit-testable.
String? roomCodeFromScannedValue(String? raw) {
  if (raw == null) return null;
  final match = _deepLinkRoomCode.firstMatch(raw.trim());
  return match?.group(1)?.toUpperCase();
}

enum _Mode { landing, scanning, enteringCode }

class MpHomeScreen extends StatefulWidget {
  const MpHomeScreen({super.key});

  @override
  State<MpHomeScreen> createState() => _MpHomeScreenState();
}

class _MpHomeScreenState extends State<MpHomeScreen>
    with WidgetsBindingObserver {
  _Mode _mode = _Mode.landing;
  final _codeController = TextEditingController();
  MobileScannerController? _scannerController;
  bool _navigated = false;
  LocalNetworkStatus _network = LocalNetworkStatus.unknown;
  bool _probing = false;
  PartyRoomBrowser? _roomBrowser;
  StreamSubscription<List<PartyHostCandidate>>? _roomSubscription;
  List<PartyHostCandidate> _nearbyRooms = const [];
  bool _searchingRooms = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensurePermissions());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _codeController.dispose();
    _scannerController?.dispose();
    unawaited(_roomSubscription?.cancel());
    unawaited(_roomBrowser?.dispose());
    super.dispose();
  }

  /// Coming back from Settings (or from the system prompt) re-checks, so the
  /// banner disappears the moment access is switched back on.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      unawaited(_stopRoomDiscovery());
    } else if (state == AppLifecycleState.resumed &&
        AppServices.of(context).multiplayerProfile.permissionsPrimerSeen) {
      _refreshNetwork();
    }
  }

  Future<void> _ensurePermissions() async {
    if (!mounted) return;
    final services = AppServices.of(context);
    final profile = services.multiplayerProfile;
    if (!profile.permissionsPrimerSeen) {
      final accepted = await showMpPermissionsPrimer(
        context,
        services.settings.locale,
      );
      if (!mounted) return;
      if (!accepted) {
        Navigator.of(context).pop();
        return;
      }
      await profile.markPermissionsPrimerSeen();
    }
    // First call after the primer is what triggers the iOS system prompt.
    await _refreshNetwork();
  }

  Future<void> _refreshNetwork() async {
    if (_probing) return;
    _probing = true;
    final status = await AppServices.of(context).localNetwork.status();
    _probing = false;
    if (!mounted) return;
    setState(() => _network = status);
    if (status == LocalNetworkStatus.granted) {
      await _startRoomDiscovery();
    } else {
      await _stopRoomDiscovery();
    }
  }

  Future<void> _startRoomDiscovery() async {
    if (_roomBrowser != null) return;
    final browser = PartyRoomBrowser();
    _roomBrowser = browser;
    setState(() => _searchingRooms = true);
    _roomSubscription = browser.rooms.listen((rooms) {
      if (!mounted) return;
      setState(() {
        _nearbyRooms = rooms;
        _searchingRooms = false;
      });
    });
    await browser.start();
  }

  Future<void> _stopRoomDiscovery() async {
    await _roomSubscription?.cancel();
    _roomSubscription = null;
    final browser = _roomBrowser;
    _roomBrowser = null;
    if (browser != null) await browser.dispose();
    if (mounted) {
      setState(() {
        _nearbyRooms = const [];
        _searchingRooms = false;
      });
    }
  }

  void _openSettings() {
    final services = AppServices.of(context);
    services.sound.button();
    services.localNetwork.openAppSettings();
  }

  void _startScan() {
    _scannerController ??= MobileScannerController();
    setState(() => _mode = _Mode.scanning);
  }

  void _onDetect(BarcodeCapture capture) {
    if (_navigated) return;
    for (final barcode in capture.barcodes) {
      final code = roomCodeFromScannedValue(barcode.rawValue);
      if (code != null) {
        _navigated = true;
        _goToJoin(code);
        return;
      }
    }
  }

  void _goToJoin(String roomCode) {
    final services = AppServices.of(context);
    services.sound.button();
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => MpJoinScreen(roomCode: roomCode)),
    );
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
          switch (_mode) {
            case _Mode.landing:
              return _Landing(
                t: t,
                networkDenied: _network == LocalNetworkStatus.denied,
                nearbyRooms: _nearbyRooms,
                searchingRooms: _searchingRooms,
                onJoinRoom: (room) => _goToJoin(room.roomCode),
                onOpenSettings: _openSettings,
                onScan: _startScan,
                onEnterCode: () => setState(() => _mode = _Mode.enteringCode),
              );
            case _Mode.scanning:
              return _Scanning(
                t: t,
                controller: _scannerController!,
                onDetect: _onDetect,
                onOpenSettings: _openSettings,
                onBack: () => setState(() => _mode = _Mode.landing),
              );
            case _Mode.enteringCode:
              return _EnterCode(
                t: t,
                controller: _codeController,
                onBack: () => setState(() => _mode = _Mode.landing),
                onJoin: () {
                  final code = _codeController.text.trim().toUpperCase();
                  if (code.length != 4) return;
                  services.sound.button();
                  _goToJoin(code);
                },
              );
          }
        },
      ),
    );
  }
}

class _Landing extends StatelessWidget {
  const _Landing({
    required this.t,
    required this.networkDenied,
    required this.nearbyRooms,
    required this.searchingRooms,
    required this.onJoinRoom,
    required this.onOpenSettings,
    required this.onScan,
    required this.onEnterCode,
  });

  final String Function(String, [Map<String, String>?]) t;
  final bool networkDenied;
  final List<PartyHostCandidate> nearbyRooms;
  final bool searchingRooms;
  final ValueChanged<PartyHostCandidate> onJoinRoom;
  final VoidCallback onOpenSettings;
  final VoidCallback onScan;
  final VoidCallback onEnterCode;

  @override
  Widget build(BuildContext context) {
    return MpBackground(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          BalancedText(
            t('ui.mp.home.title'),
            style: Ays.title(56),
            maxLines: 1,
          ),
          const SizedBox(height: 14),
          Text(
            t('ui.mp.home.tagline'),
            textAlign: TextAlign.center,
            style: Ays.label(16, color: Ays.inkDim),
          ),
          if (networkDenied) ...[
            const SizedBox(height: 24),
            MpPermissionNotice(
              message: t('ui.mp.permission.network_denied'),
              actionLabel: t('ui.mp.permission.open_settings'),
              onAction: onOpenSettings,
            ),
          ],
          const SizedBox(height: 28),
          if (!networkDenied) ...[
            Row(
              children: [
                Text(
                  t('ui.mp.home.nearby'),
                  style: Ays.label(13, color: Ays.yellow),
                ),
                const Spacer(),
                if (searchingRooms)
                  const Icon(
                    Icons.wifi_find_rounded,
                    size: 18,
                    color: Ays.inkDim,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (nearbyRooms.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 20,
                ),
                decoration: BoxDecoration(
                  color: Ays.surface,
                  borderRadius: Ays.radiusSmall,
                  border: Border.all(color: Ays.surfaceHigh),
                ),
                child: Text(
                  t('ui.mp.home.searching'),
                  textAlign: TextAlign.center,
                  style: Ays.label(13, color: Ays.inkDim),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 224),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: nearbyRooms.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final room = nearbyRooms[index];
                    return _NearbyRoomCard(
                      room: room,
                      t: t,
                      onTap: () => onJoinRoom(room),
                    );
                  },
                ),
              ),
            const SizedBox(height: 20),
          ],
          AysButton(
            label: t('ui.mp.home.scan'),
            height: 78,
            fontSize: 28,
            onTap: onScan,
          ),
          const SizedBox(height: 12),
          AysButton(
            label: t('ui.mp.home.enter_code'),
            height: 66,
            fontSize: 22,
            outlined: true,
            onTap: onEnterCode,
          ),
          const Spacer(),
          AysButton(
            label: t('ui.mp.home.back'),
            height: 58,
            fontSize: 18,
            outlined: true,
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

class _NearbyRoomCard extends StatelessWidget {
  const _NearbyRoomCard({
    required this.room,
    required this.t,
    required this.onTap,
  });

  final PartyHostCandidate room;
  final String Function(String, [Map<String, String>?]) t;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final canJoin = room.canJoin;
    return Semantics(
      button: canJoin,
      label: '${room.displayName}, ${room.playerCount} of ${room.maxPlayers}',
      child: InkWell(
        onTap: canJoin ? onTap : null,
        borderRadius: Ays.radiusSmall,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: canJoin ? Ays.surface : Ays.surface.withValues(alpha: 0.55),
            borderRadius: Ays.radiusSmall,
            border: Border.all(
              color: canJoin ? Ays.purple : Ays.surfaceHigh,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Ays.purple,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.tv_rounded, color: Ays.ink, size: 24),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      room.displayName.toUpperCase(),
                      style: Ays.label(17),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      t('ui.mp.home.players', {
                        'n': '${room.playerCount}',
                        'max': '${room.maxPlayers}',
                      }),
                      style: Ays.label(12, color: Ays.inkDim),
                    ),
                  ],
                ),
              ),
              Text(
                canJoin ? t('ui.mp.home.join') : t('ui.mp.home.in_progress'),
                style: Ays.label(12, color: canJoin ? Ays.yellow : Ays.inkDim),
              ),
              if (canJoin) ...[
                const SizedBox(width: 5),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: Ays.yellow,
                  size: 18,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EnterCode extends StatelessWidget {
  const _EnterCode({
    required this.t,
    required this.controller,
    required this.onBack,
    required this.onJoin,
  });

  final String Function(String, [Map<String, String>?]) t;
  final TextEditingController controller;
  final VoidCallback onBack;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    return MpBackground(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(flex: 2),
          BalancedText(t('ui.mp.enter_code.title'), style: Ays.title(40)),
          const SizedBox(height: 24),
          MpTextField(
            controller: controller,
            hint: t('ui.mp.enter_code.hint'),
            textAlign: TextAlign.center,
            textCapitalization: TextCapitalization.characters,
            maxLength: 4,
            autofocus: true,
            onSubmitted: (_) => onJoin(),
          ),
          const Spacer(flex: 3),
          AysButton(
            label: t('ui.mp.enter_code.join'),
            height: 78,
            fontSize: 28,
            onTap: onJoin,
          ),
          const SizedBox(height: 12),
          AysButton(
            label: t('ui.mp.home.back'),
            height: 58,
            fontSize: 18,
            outlined: true,
            onTap: onBack,
          ),
        ],
      ),
    );
  }
}

class _Scanning extends StatelessWidget {
  const _Scanning({
    required this.t,
    required this.controller,
    required this.onDetect,
    required this.onOpenSettings,
    required this.onBack,
  });

  final String Function(String, [Map<String, String>?]) t;
  final MobileScannerController controller;
  final void Function(BarcodeCapture) onDetect;
  final VoidCallback onOpenSettings;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: controller,
            onDetect: onDetect,
            errorBuilder: (context, error) => MpBackground(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      t('ui.mp.scan.permission_denied'),
                      textAlign: TextAlign.center,
                      style: Ays.label(18),
                    ),
                    const SizedBox(height: 20),
                    AysButton(
                      label: t('ui.mp.permission.open_settings'),
                      height: 58,
                      fontSize: 18,
                      onTap: onOpenSettings,
                    ),
                    const SizedBox(height: 12),
                    AysButton(
                      label: t('ui.mp.home.back'),
                      height: 58,
                      fontSize: 18,
                      outlined: true,
                      onTap: onBack,
                    ),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AysButton(
                    label: t('ui.mp.home.back'),
                    height: 52,
                    fontSize: 16,
                    onTap: onBack,
                  ),
                  const Spacer(),
                  Text(
                    t('ui.mp.scan.hint'),
                    textAlign: TextAlign.center,
                    style: Ays.label(16, color: Ays.ink),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
