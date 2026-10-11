/// "✓ JOINED … waiting for players" + roster + self ready toggle
/// ([[Multiplayer Client (Mobile)]] "Mobile — join", after-join state).
///
/// Starting the match is TV-only ([[Multiplayer Product]] "TV — lobby"): this
/// screen never shows a START GAME button, only READY.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../ai/apple_ai_service.dart';
import '../../../i18n/strings.dart';
import '../../../multiplayer/engine/party_session.dart';
import '../../../multiplayer/engine/party_state.dart';
import '../../../multiplayer/protocol/protocol.dart';
import '../../../multiplayer/presenter/spoken_identity.dart';
import '../../../services/app_services.dart';
import '../../../services/purchases/purchase_manager.dart';
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
  bool _reportedPartyPack = false;
  PurchaseManager? _purchases;
  SpokenIdentity? _spokenIdentity;
  bool _nameAnalysisStarted = false;
  bool _analyzingName = false;
  final ValueNotifier<int> _identityRevision = ValueNotifier<int>(0);

  PartySession get _session => widget.session;

  @override
  void initState() {
    super.initState();
    _state = _session.state;
    _statesSub = _session.states.listen((s) => setState(() => _state = s));
    _eventsSub = _session.events.listen(_onEvent);
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
    if (!_nameAnalysisStarted) {
      _nameAnalysisStarted = true;
      final profile = AppServices.of(context).multiplayerProfile;
      _spokenIdentity = profile.spokenIdentityFor(profile.playerName);
      if (_spokenIdentity!.needsAi) unawaited(_analyzeName());
    }
  }

  Future<void> _analyzeName() async {
    final services = AppServices.of(context);
    final name = services.multiplayerProfile.playerName;
    setState(() => _analyzingName = true);
    Map<String, Object?>? result;
    final local = AppleAiMethodChannel();
    final availability = await local.available();
    if (availability.isAvailable) {
      result = await local.analyzeSpokenName(
        unitId: 'name-${DateTime.now().microsecondsSinceEpoch}',
        displayName: name,
        locale: services.settings.locale,
      );
    }
    if (result == null) {
      final remote = await _session.requestNameAnalysis(name);
      if (remote != null) {
        result = {
          'decision': remote.decision,
          'spokenName': remote.spokenName,
          'confidence': remote.confidence,
        };
      }
    }
    if (!mounted) return;
    final identity = result == null
        ? SpokenIdentity(
            displayName: name,
            policy: NameSpeechPolicy.displayOnly,
          )
        : SpokenIdentity.fromAi(
            displayName: name,
            decision: result['decision'] as String? ?? 'displayOnly',
            spokenName: result['spokenName'] as String?,
            confidence: (result['confidence'] as num?)?.toDouble() ?? 0,
          );
    await services.multiplayerProfile.setProfile(
      playerName: name,
      emoji: services.multiplayerProfile.emoji,
      spokenIdentity: identity,
    );
    _session.updatePlayerIdentity(
      playerName: name,
      spokenName: identity.spokenName,
      speechPolicy: identity.policy.name,
    );
    if (mounted) {
      setState(() {
        _spokenIdentity = identity;
        _analyzingName = false;
      });
      _identityRevision.value++;
    }
  }

  Future<void> _showNameCard() async {
    final services = AppServices.of(context);
    String t(String key, [Map<String, String>? args]) =>
        Strings.t(services.settings.locale, key, args);
    final controller = TextEditingController(
      text: services.multiplayerProfile.playerName,
    );
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Ays.surface,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BalancedText(t('ui.mp.name_card.title'), style: Ays.title(26)),
            const SizedBox(height: 16),
            MpTextField(
              controller: controller,
              hint: t('ui.mp.join.name_hint'),
            ),
            const SizedBox(height: 12),
            ValueListenableBuilder<int>(
              valueListenable: _identityRevision,
              builder: (context, revision, child) => Text(
                _analyzingName
                    ? t('ui.mp.name_card.analyzing')
                    : (_spokenIdentity?.policy == NameSpeechPolicy.blocked
                          ? t(blockedNameTauntKey(_spokenIdentity!.displayName))
                          : (_spokenIdentity?.spokenName == null
                                ? t('ui.mp.name_card.unknown')
                                : t('ui.mp.name_card.pronunciation', {
                                    'name': _spokenIdentity!.spokenName!
                                        .toUpperCase(),
                                  }))),
                textAlign: TextAlign.center,
                style: Ays.mono(12, color: Ays.inkDim),
              ),
            ),
            const SizedBox(height: 18),
            AysButton(
              label: t('ui.mp.name_card.update'),
              height: 56,
              fontSize: 17,
              onTap: () async {
                final name = controller.text.trim();
                if (name.isEmpty) return;
                final identity = SpokenIdentity.classify(name);
                if (identity.policy == NameSpeechPolicy.blocked) {
                  setState(() => _spokenIdentity = identity);
                  _identityRevision.value++;
                  return;
                }
                await services.multiplayerProfile.setProfile(
                  playerName: name,
                  emoji: services.multiplayerProfile.emoji,
                  spokenIdentity: identity,
                );
                _session.updatePlayerIdentity(
                  playerName: name,
                  spokenName: identity.needsAi ? null : identity.spokenName,
                  speechPolicy: identity.needsAi
                      ? NameSpeechPolicy.displayOnly.name
                      : identity.policy.name,
                );
                if (context.mounted) Navigator.pop(context);
                if (mounted) {
                  setState(() {
                    _spokenIdentity = identity;
                    _nameAnalysisStarted = true;
                  });
                  _identityRevision.value++;
                }
                if (identity.needsAi) unawaited(_analyzeName());
              },
            ),
          ],
        ),
      ),
    );
    controller.dispose();
  }

  @override
  void dispose() {
    _statesSub?.cancel();
    _eventsSub?.cancel();
    _purchases?.removeListener(_onPurchaseChanged);
    _identityRevision.dispose();
    if (!_navigated) unawaited(_session.dispose());
    super.dispose();
  }

  void _onEvent(PartyEvent event) {
    if (event is PartyGameStartedEvent && !_navigated) {
      _navigated = true;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => MpGameScreen(session: _session),
        ),
      );
    }
    if (event is PartyPackNudgeEvent) {
      AppServices.of(context).haptics.wrong();
    }
  }

  void _onPurchaseChanged() {
    if (!mounted) return;
    final services = AppServices.of(context);
    if (services.settings.partyCapacityUnlocked && !_reportedPartyPack) {
      _reportedPartyPack = true;
      _session.updateRoomEntitlements(
        noAds: services.settings.adsRemoved,
        partyPack: true,
      );
    } else if (services.settings.adsRemoved) {
      _session.updateRoomEntitlements(
        noAds: true,
        partyPack: services.settings.partyCapacityUnlocked,
      );
    }
    setState(() {});
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
              MpBackground(child: _buildBody(t, services)),
              if (_state.phase == PartyPhase.disconnected ||
                  _state.phase == PartyPhase.rejected)
                MpDisconnectView(
                  session: _session,
                  state: _state,
                  locale: locale,
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBody(
    String Function(String, [Map<String, String>?]) t,
    AppServices services,
  ) {
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
        if (_analyzingName ||
            _spokenIdentity?.policy == NameSpeechPolicy.displayOnly ||
            _spokenIdentity?.policy == NameSpeechPolicy.blocked) ...[
          InkWell(
            onTap: _showNameCard,
            borderRadius: Ays.radiusSmall,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Ays.surfaceHigh,
                borderRadius: Ays.radiusSmall,
                border: Border.all(color: Ays.warning),
              ),
              child: Text(
                _analyzingName
                    ? t('ui.mp.name_card.analyzing')
                    : (_spokenIdentity?.policy == NameSpeechPolicy.blocked
                          ? t(blockedNameTauntKey(_spokenIdentity!.displayName))
                          : t('ui.mp.name_card.tap_to_fix')),
                textAlign: TextAlign.center,
                style: Ays.mono(12, color: Ays.warning),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
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
        if (_state.partyPackActive)
          _PartyPackActiveBanner(t: t)
        else if (_state.players.length >= 8)
          _PartyPackBanner(
            t: t,
            pulse: _state.partyPackNudgeSerial,
            price: services.purchases.partyPackProduct?.price,
            bundlePrice: services.purchases.partyBundleProduct?.price,
            busy: services.purchases.busy,
            onBuy: services.purchases.partyPackProduct == null
                ? null
                : services.purchases.buyPartyPack,
            onBuyBundle: services.purchases.partyBundleProduct == null
                ? null
                : services.purchases.buyPartyBundle,
          ),
        if (_state.partyPackActive || _state.players.length >= 8)
          const SizedBox(height: 12),
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

class _PartyPackActiveBanner extends StatelessWidget {
  const _PartyPackActiveBanner({required this.t});
  final String Function(String, [Map<String, String>?]) t;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [Ays.warning, Ays.pink]),
      borderRadius: Ays.radiusSmall,
      boxShadow: [
        BoxShadow(color: Ays.warning.withValues(alpha: .35), blurRadius: 22),
      ],
    ),
    child: Column(
      children: [
        Text(
          t('ui.mp.party.active'),
          textAlign: TextAlign.center,
          style: Ays.title(20).copyWith(color: Ays.bg),
        ),
        Text(
          t('ui.mp.party.active_body'),
          textAlign: TextAlign.center,
          style: Ays.label(12, color: Ays.bg),
        ),
      ],
    ),
  );
}

class _PartyPackBanner extends StatefulWidget {
  const _PartyPackBanner({
    required this.t,
    required this.pulse,
    required this.price,
    required this.bundlePrice,
    required this.busy,
    required this.onBuy,
    required this.onBuyBundle,
  });
  final String Function(String, [Map<String, String>?]) t;
  final int pulse;
  final String? price;
  final String? bundlePrice;
  final bool busy;
  final Future<void> Function()? onBuy;
  final Future<void> Function()? onBuyBundle;
  @override
  State<_PartyPackBanner> createState() => _PartyPackBannerState();
}

class _PartyPackBannerState extends State<_PartyPackBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );
  @override
  void didUpdateWidget(covariant _PartyPackBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pulse != oldWidget.pulse) _shake.forward(from: 0);
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _shake,
    builder: (context, child) {
      final x = _shake.isAnimating
          ? (1 - _shake.value) *
                10 *
                ((_shake.value * 8).floor().isEven ? 1 : -1)
          : 0.0;
      return Transform.translate(offset: Offset(x, 0), child: child);
    },
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Ays.surfaceHigh,
        borderRadius: Ays.radiusSmall,
        border: Border.all(color: Ays.warning, width: 2),
      ),
      child: Column(
        children: [
          Text(
            widget.t('ui.mp.party.full'),
            textAlign: TextAlign.center,
            style: Ays.title(18),
          ),
          const SizedBox(height: 4),
          Text(
            widget.t('ui.mp.party.one_unlocks'),
            textAlign: TextAlign.center,
            style: Ays.label(12, color: Ays.inkDim),
          ),
          if (widget.onBuy != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: AysButton(
                    label: widget.t('ui.mp.party.buy', {
                      'price': widget.price ?? '',
                    }),
                    height: 58,
                    fontSize: 13,
                    color: Ays.warning,
                    onTap: () {
                      if (!widget.busy) widget.onBuy?.call();
                    },
                  ),
                ),
                if (widget.onBuyBundle != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: AysButton(
                      label: widget.t('ui.mp.party.buy_bundle', {
                        'price': widget.bundlePrice ?? '',
                      }),
                      height: 58,
                      fontSize: 13,
                      color: Ays.pink,
                      onTap: () {
                        if (!widget.busy) widget.onBuyBundle?.call();
                      },
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    ),
  );
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
          MpAvatar(
            seed: player.playerId,
            name: player.playerName,
            emoji: player.emoji,
          ),
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
            style: Ays.label(
              20,
              color: player.ready ? Ays.correct : Ays.inkDim,
            ),
          ),
        ],
      ),
    );
  }
}
