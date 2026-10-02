/// The controller's in-round screen: renders the host's canonical challenge
/// and drives it to a verdict locally, the same `Challenge` engine
/// single-player uses ([[Multiplayer Client (Mobile)]]; see the
/// design-change note on `PlayerAction` in
/// `lib/multiplayer/protocol/protocol.dart` for why judging moved here
/// rather than staying host-side).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../core/challenge.dart';
import '../../../i18n/app_locale.dart';
import '../../../i18n/strings.dart';
import '../../../multiplayer/engine/party_controller.dart';
import '../../../multiplayer/engine/party_session.dart';
import '../../../multiplayer/engine/party_state.dart';
import '../../../services/app_services.dart';
import '../../theme.dart';
import '../../widgets/challenge_renderer.dart';
import '../../widgets/flash_overlay.dart';
import 'mp_disconnect_view.dart';
import 'mp_result_screen.dart';

class MpGameScreen extends StatefulWidget {
  const MpGameScreen({super.key, required this.session});

  final PartySession session;

  @override
  State<MpGameScreen> createState() => _MpGameScreenState();
}

class _MpGameScreenState extends State<MpGameScreen>
    with SingleTickerProviderStateMixin {
  late final PartyController _controller = PartyController(widget.session);
  late final Ticker _ticker;
  final TapClaim _claim = TapClaim();
  late PartyState _state;
  StreamSubscription<PartyState>? _statesSub;
  StreamSubscription<PartyEvent>? _eventsSub;
  bool _navigated = false;

  /// The ticker's own elapsed time at the moment the current round went GO
  /// — `PartySession.tick` wants elapsed *since GO*, not since this widget
  /// mounted, and the ticker runs continuously across every round on this
  /// screen. Reset on every `RoundStart` (see `_onEvent`) so a stray tick
  /// from a just-finished round can never leak into the next one.
  Duration? _goAtTickerElapsed;
  String? _tickingRoundId;

  PartySession get _session => widget.session;

  @override
  void initState() {
    super.initState();
    _state = _session.state;
    _statesSub = _session.states.listen((s) => setState(() => _state = s));
    _eventsSub = _session.events.listen(_onEvent);
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _statesSub?.cancel();
    _eventsSub?.cancel();
    if (!_navigated) unawaited(_session.dispose());
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final round = _state.round;
    if (round == null || !round.isGo) return;
    if (_tickingRoundId != round.id) {
      // First tick after this round went GO — start its clock here rather
      // than at whatever elapsed the ticker happened to be at (it runs
      // continuously across the whole screen's lifetime, every round).
      _tickingRoundId = round.id;
      _goAtTickerElapsed = elapsed;
    }
    final goAt = _goAtTickerElapsed;
    if (goAt == null) return;
    _session.tick(elapsed - goAt);
  }

  void _onEvent(PartyEvent event) {
    if (event is PartyRoundStartedEvent) {
      _tickingRoundId = null;
      _goAtTickerElapsed = null;
    }
    if (event is PartyGameEndEvent && !_navigated) {
      _navigated = true;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => MpResultScreen(session: _session)),
      );
    }
  }

  void _onBackgroundDown() {
    if (_claim.consumeDown()) return;
    _controller.onBackgroundTap();
  }

  void _onTarget(String id, int index, TapKind kind) {
    if (kind != TapKind.down) return;
    _controller.onTargetTap(TargetSpec(id: id));
  }

  @override
  Widget build(BuildContext context) {
    final services = AppServices.of(context);
    return Scaffold(
      body: AnimatedBuilder(
        animation: services.settings,
        builder: (context, _) {
          final locale = services.settings.locale;
          return Container(
            decoration: const BoxDecoration(gradient: Ays.pageGradient),
            child: Stack(
              children: [
                Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (_) => _onBackgroundDown(),
                  child: SafeArea(child: _buildBody(locale)),
                ),
                if (_showResultFlash)
                  FlashOverlay(
                    correct: _state.privateResult!.correct,
                    message: Strings.t(
                      locale,
                      _state.privateResult!.correct ? 'ui.mp.game.correct' : 'ui.mp.game.wrong',
                    ),
                  ),
                if (_isEliminated)
                  Positioned(
                    top: 12,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: _Badge(text: Strings.t(locale, 'ui.mp.game.eliminated')),
                    ),
                  ),
                if (_state.phase == PartyPhase.disconnected || _state.phase == PartyPhase.rejected)
                  MpDisconnectView(session: _session, state: _state, locale: locale),
              ],
            ),
          );
        },
      ),
    );
  }

  bool get _showResultFlash => _state.round != null && _state.privateResult != null;

  bool get _isEliminated => _state.standings[_state.selfClientId]?.eliminated ?? false;

  Widget _buildBody(AppLocale locale) {
    final round = _state.round;
    if (round == null) {
      return Center(
        child: Text(
          Strings.t(locale, 'ui.mp.game.waiting_round'),
          textAlign: TextAlign.center,
          style: Ays.title(44),
        ),
      );
    }
    if (!round.isGo) {
      return Center(
        child: Text(
          Strings.t(locale, 'ui.mp.game.waiting_round'),
          textAlign: TextAlign.center,
          style: Ays.title(44),
        ),
      );
    }
    return ChallengeRenderer(view: round.view, claim: _claim, onTarget: _onTarget);
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(color: Ays.surfaceHigh, borderRadius: Ays.radiusSmall),
        child: Text(text, style: Ays.label(13)),
      );
}
